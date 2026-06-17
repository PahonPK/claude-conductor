# Verify Recipe Snippets (per stack)

> Paste the matching block into a project CLAUDE.md `## Memory Persistence →
> Verify recipe` section. A verify recipe = 3–7 **read-only** commands that check
> whether the project memory still matches reality. Run when `Last verified` > 5 days.
> Source: `../MEMORY_SCHEME.md` §Verify recipe examples per stack.

---

## Next.js + Supabase
```bash
git status --short
git log --oneline -10
ls supabase/migrations/ | tail -5
node -e "const m=require('./src/lib/modules.ts').modules; console.log(m.length, 'modules')"  # or read file
find src/app -name "page.tsx" | wc -l
npx tsc --noEmit 2>&1 | tail -3
```

## Vite + React + Supabase
```bash
git status --short
git log --oneline -10
ls src/pages/
cat src/App.tsx | grep -i "<Route" | head -10
ls supabase/migrations/ 2>/dev/null | tail -5
```

## Workflow-automation project (e.g. n8n / Make)
```bash
# Vendor-neutral form. For n8n: ~/.n8n-api-key + header "X-N8N-API-KEY".
API_KEY=$(cat ~/.automation-api-key)
curl -sS -H "X-API-KEY: $API_KEY" "<AUTOMATION_BASE_URL>/api/v1/workflows/<ID>" \
  | node -e "const w=JSON.parse(require('fs').readFileSync(0)); console.log('v'+w.versionCounter, w.active, w.nodes.length+'nodes')"
curl -sS -H "X-API-KEY: $API_KEY" "<AUTOMATION_BASE_URL>/api/v1/executions?workflowId=<ID>&limit=5"
```

## WordPress / hosted site
```bash
curl -sI https://<domain> | head -5  # status + headers
# check cert expiry
echo | openssl s_client -servername <domain> -connect <domain>:443 2>/dev/null | openssl x509 -noout -enddate
# (if WP) check version
curl -s https://<domain>/wp-json | jq -r '.namespaces[]' 2>/dev/null | head -3
```

## Static / IIS site
```bash
curl -sI https://<domain> | head -5
curl -sI https://<domain>/robots.txt | head -3
curl -sI https://<domain>/sitemap.xml | head -3
```
