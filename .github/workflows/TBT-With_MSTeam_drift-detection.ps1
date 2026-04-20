name: Terraform Configuration Drift Detection

on:
  workflow_dispatch:
  schedule:
    - cron: '41 3 * * *'   # Runs nightly at 3:41 AM UTC

permissions:
  id-token: write
  contents: read
  issues: write

jobs:
  terraform-plan:
    name: Terraform Drift Detection Plan
    runs-on: ubuntu-latest
    env:
      ARM_SKIP_PROVIDER_REGISTRATION: true

    outputs:
      tfplanExitCode: ${{ steps.tf-plan.outputs.exitcode }}

    steps:
      # ------- Step 1: Checkout Code -------
      - name: Checkout Repository
        uses: actions/checkout@v4

      # ------- Step 2: Azure Login via OIDC -------
      - name: Azure Login via OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      # ------- Step 3: Setup Terraform -------
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"
          terraform_wrapper: false

      # ------- Step 4: Terraform Init -------
      - name: Terraform Init
        run: terraform init
        env:
          ARM_CLIENT_ID:       ${{ secrets.AZURE_CLIENT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_TENANT_ID:       ${{ secrets.AZURE_TENANT_ID }}
          ARM_USE_OIDC:        "true"

      # ------- Step 5: Terraform Plan (Drift Check) -------
      - name: Terraform Plan
        id: tf-plan
        run: |
          export exitcode=0
          terraform plan -detailed-exitcode -no-color -out tfplan || export exitcode=$?

          echo "exitcode=$exitcode" >> $GITHUB_OUTPUT

          if [ $exitcode -eq 1 ]; then
            echo "Terraform Plan Failed!"
            exit 1
          else
            exit 0
          fi
        env:
          ARM_CLIENT_ID:       ${{ secrets.AZURE_CLIENT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_TENANT_ID:       ${{ secrets.AZURE_TENANT_ID }}
          ARM_USE_OIDC:        "true"

      # ------- Step 6: Upload Plan Artifact -------
      - name: Publish Terraform Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: tfplan
          retention-days: 5

      # ------- Step 7: Create Readable Plan Output -------
      - name: Create String Output
        id: tf-plan-string
        run: |
          TERRAFORM_PLAN=$(terraform show -no-color tfplan)

          delimiter="$(openssl rand -hex 8)"
          echo "summary<<${delimiter}" >> $GITHUB_OUTPUT
          echo "## Terraform Drift Detection Report" >> $GITHUB_OUTPUT
          echo "**Repo:** \`${{ github.repository }}\`" >> $GITHUB_OUTPUT
          echo "**Run:** \`${{ github.run_id }}\`" >> $GITHUB_OUTPUT
          echo "**Triggered by:** \`${{ github.event_name }}\`" >> $GITHUB_OUTPUT
          echo "" >> $GITHUB_OUTPUT
          echo "<details><summary>Click to expand full plan</summary>" >> $GITHUB_OUTPUT
          echo "" >> $GITHUB_OUTPUT
          echo '```terraform' >> $GITHUB_OUTPUT
          echo "$TERRAFORM_PLAN" >> $GITHUB_OUTPUT
          echo '```' >> $GITHUB_OUTPUT
          echo "</details>" >> $GITHUB_OUTPUT
          echo "${delimiter}" >> $GITHUB_OUTPUT

      # ------- Step 8: Publish to GitHub Actions Summary -------
      - name: Publish Plan to Step Summary
        env:
          SUMMARY: ${{ steps.tf-plan-string.outputs.summary }}
        run: echo "$SUMMARY" >> $GITHUB_STEP_SUMMARY

      # ------- Step 9: Open/Update GitHub Issue if Drift Detected -------
      - name: Publish Drift Report — Create or Update Issue
        if: steps.tf-plan.outputs.exitcode == 2
        uses: actions/github-script@v7
        env:
          SUMMARY: ${{ steps.tf-plan-string.outputs.summary }}
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const body  = `${process.env.SUMMARY}`;
            const title = 'Terraform Configuration Drift Detected';
            const creator = 'github-actions[bot]';

            const issues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              creator: creator,
              title: title
            });

            if (issues.data.length > 0) {
              const issue = issues.data[0];
              if (issue.body == body) {
                console.log('Drift issue already up to date — no changes needed');
              } else {
                console.log('Drift issue found — updating with latest plan');
                await github.rest.issues.update({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  issue_number: issue.number,
                  body: body
                });
              }
            } else {
              console.log('New drift detected — creating GitHub issue');
              await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: title,
                body: body,
                labels: ['drift-detection', 'terraform']
              });
            }

      # ------- Step 10: ✅ NEW — Notify MS Teams if Drift Detected -------
      - name: Notify Teams — Drift Detected
        if: steps.tf-plan.outputs.exitcode == 2
        run: |
          RUN_URL="https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"

          curl -s -X POST "${{ secrets.TEAMS_WEBHOOK_URL }}" \
          -H "Content-Type: application/json" \
          -d '{
            "@type": "MessageCard",
            "@context": "https://schema.org/extensions",
            "themeColor": "FF0000",
            "summary": "Terraform Drift Detected",
            "sections": [{
              "activityTitle": "⚠️ Terraform Configuration Drift Detected",
              "activitySubtitle": "Repository: ${{ github.repository }}",
              "activityImage": "https://www.datocms-assets.com/2885/1620155116-brandhcterraformverticalcolor.png",
              "facts": [
                { "name": "Repository",   "value": "${{ github.repository }}" },
                { "name": "Branch",       "value": "${{ github.ref_name }}" },
                { "name": "Triggered by", "value": "${{ github.event_name }}" },
                { "name": "Run ID",       "value": "${{ github.run_id }}" },
                { "name": "Status",       "value": "DRIFT DETECTED - Resources changed outside Terraform" }
              ],
              "markdown": true
            }],
            "potentialAction": [{
              "@type": "OpenUri",
              "name": "View Full Drift Report",
              "targets": [{
                "os": "default",
                "uri": "'"$RUN_URL"'"
              }]
            }]
          }'

      # ------- Step 11: ✅ NEW — Notify MS Teams if No Drift -------
      - name: Notify Teams — All Clean
        if: steps.tf-plan.outputs.exitcode == 0
        run: |
          RUN_URL="https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"

          curl -s -X POST "${{ secrets.TEAMS_WEBHOOK_URL }}" \
          -H "Content-Type: application/json" \
          -d '{
            "@type": "MessageCard",
            "@context": "https://schema.org/extensions",
            "themeColor": "00C853",
            "summary": "Terraform No Drift",
            "sections": [{
              "activityTitle": "✅ Terraform — No Drift Detected",
              "activitySubtitle": "Repository: ${{ github.repository }}",
              "activityImage": "https://www.datocms-assets.com/2885/1620155116-brandhcterraformverticalcolor.png",
              "facts": [
                { "name": "Repository",   "value": "${{ github.repository }}" },
                { "name": "Branch",       "value": "${{ github.ref_name }}" },
                { "name": "Triggered by", "value": "${{ github.event_name }}" },
                { "name": "Run ID",       "value": "${{ github.run_id }}" },
                { "name": "Status",       "value": "All resources match Terraform state" }
              ],
              "markdown": true
            }],
            "potentialAction": [{
              "@type": "OpenUri",
              "name": "View Run Details",
              "targets": [{
                "os": "default",
                "uri": "'"$RUN_URL"'"
              }]
            }]
          }'

      # ------- Step 12: Close Issue if No Drift -------
      - name: Resolve Drift Report — Close Issue if Clean
        if: steps.tf-plan.outputs.exitcode == 0
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const title   = 'Terraform Configuration Drift Detected';
            const creator = 'github-actions[bot]';

            const issues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              creator: creator,
              title: title
            });

            if (issues.data.length > 0) {
              const issue = issues.data[0];
              console.log('No drift detected — closing existing issue #' + issue.number);
              await github.rest.issues.update({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: issue.number,
                state: 'closed'
              });
            } else {
              console.log('No drift detected and no open issues — all clean!');
            }

      # ------- Step 13: Azure Logout -------
      - name: Azure Logout
        if: always()
        run: az logout

      # ------- Step 14: Fail Workflow if Drift Found -------
      - name: Fail on Drift Detected
        if: steps.tf-plan.outputs.exitcode == 2
        run: |
          echo "Drift detected! Check the GitHub issue and Teams notification for details."
          exit 1