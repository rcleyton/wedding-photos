# Armazenamento de fotos

A aplicação usa somente Active Storage para armazenar e acessar arquivos.
Cada Photo continua representando um arquivo.

- Desenvolvimento usa explicitamente `local`, em `storage/`.
- Specs usam explicitamente `test`, em `tmp/storage`, sem storage externo.
- Produção escolhe um serviço de `config/storage.yml` pela variável
  `ACTIVE_STORAGE_SERVICE`. O padrão é `local`.

## Usar S3-compatible em produção

Configure as variáveis no ambiente de produção e reinicie a aplicação:

| Variável | Valor |
| --- | --- |
| `ACTIVE_STORAGE_SERVICE` | `s3_compatible` para S3-compatible ou `local` para Disk |
| `S3_ACCESS_KEY_ID` | Identificador de acesso do provedor |
| `S3_SECRET_ACCESS_KEY` | Chave secreta do provedor |
| `S3_REGION` | Região do bucket; para R2, `auto` |
| `S3_BUCKET` | Nome do bucket existente |
| `S3_ENDPOINT` | URL HTTPS do endpoint, quando exigido pelo provedor |

AWS S3 normalmente não precisa de `S3_ENDPOINT`: deixe a variável ausente ou
vazia e informe a região do bucket. Provedores como Cloudflare R2 usam endpoint
próprio, por exemplo `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`.
Veja o [exemplo oficial do R2 com o SDK Ruby](https://developers.cloudflare.com/r2/examples/aws/aws-sdk-ruby/).

O serviço usa o adapter S3 do Active Storage com a dependência `aws-sdk-s3`.
Nenhuma mudança em models, controllers ou no formulário é necessária para
selecionar o serviço. As variáveis S3 não são necessárias para `local` ou `test`.
Não coloque credenciais reais no repositório.

A seleção vale para novos arquivos. Active Storage registra o serviço de cada
blob; arquivos existentes não são transferidos automaticamente. Mantenha o
serviço e os arquivos antigos acessíveis até uma eventual migração dos dados.
