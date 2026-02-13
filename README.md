# app-nginx

Imagem Docker e deploy Helm para a aplicação Nginx.

- **Container registry:** GHCR (`ghcr.io/eng-devops/app-nginx`)
- **Helm templates:** [eng-devops/helm-templates](https://github.com/eng-devops/helm-templates) (chart `apps/nginx`)

## Pipeline

- **feature/*** → build + deploy **dev**
- **release/*** → build + deploy **stg**
- **main** → build + deploy **prd**

Build: Docker image + Helm package (.tgz) enviados para GHCR.
