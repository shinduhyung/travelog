$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Push-Location $taskRoot
try {
  node -e "require('./functions/discover/poll_model').validate(require('./functions/discover/polls.json')); console.log('Poll schedule valid');"
  if ($LASTEXITCODE -ne 0) { throw 'Invalid poll schedule' }
  gcloud storage cp functions/discover/polls.json gs://proboscis-2025.firebasestorage.app/config/travelog_polls.json
  if ($LASTEXITCODE -ne 0) { throw 'Poll schedule upload failed' }
} finally { Pop-Location }
