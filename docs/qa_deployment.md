# Preparação para QA

QA utiliza `RAILS_ENV=production`. Esta documentação não executa nem configura
o servidor. Nenhum banco, volume, domínio ou serviço remoto foi criado.

## Runtime e servidor

- Usar **Ruby 4.0.5**, declarado em `.ruby-version`, Gemfile e lockfile.
- Posteriormente instalar Ruby 4.0.5 lado a lado via RVM. O Ruby 3.3.4 e o
  aplicativo que o utiliza devem permanecer intactos; não trocar o Ruby global.
- Usar a versão de Bundler indicada em `Gemfile.lock`.
- PostgreSQL e bibliotecas de compilação da gem `pg` devem estar disponíveis.
- Nginx/Passenger já existem: descobrir no servidor os caminhos reais do RVM,
  Ruby e Passenger e verificar compatibilidade com Ruby 4.0.5. A seleção do
  interpretador deve ser específica deste aplicativo. Não assumir paths.
- Não iniciar Puma e Passenger simultaneamente para servir esta aplicação.
  Passenger não usa `config/puma.rb`; seus limites serão configurados depois.

## Variáveis de ambiente

| Variável | Uso |
| --- | --- |
| `RAILS_ENV` | `production` |
| `RAILS_MASTER_KEY` | Chave correspondente às credentials criptografadas; fornecer como segredo |
| `DATABASE_URL` | URL PostgreSQL completa do banco principal de QA |
| `CACHE_DATABASE_URL` | URL PostgreSQL completa do banco Solid Cache |
| `QUEUE_DATABASE_URL` | URL PostgreSQL completa do banco Solid Queue |
| `CABLE_DATABASE_URL` | URL PostgreSQL completa do banco Solid Cable |
| `ACTIVE_STORAGE_SERVICE` | `qa_disk` para o volume montado |
| `ACTIVE_STORAGE_ROOT` | Caminho absoluto real do diretório no volume, gravável pelo processo Rails |
| `RAILS_LOG_LEVEL` | Opcional; padrão `info` |
| `APP_HOST` | Host real, sem protocolo, para links de email em produção |
| `RAILS_MAX_THREADS` | Para Puma em QA, começar com `2` |
| `WEB_CONCURRENCY` | Para Puma, `0` mantém modo single, sem workers de cluster |
| `JOB_CONCURRENCY` | `1` para o worker Solid Queue |
| `PORT`, `PIDFILE` | Opcionais, apenas se usar Puma; valores definidos no servidor |

As URLs de banco devem conter host, nome, usuário e senha apropriados. Rails
resolve `DATABASE_URL` para primary e as variáveis nomeadas para os outros
bancos. Definir somente `DATABASE_URL` não configura os três bancos auxiliares.
Não apontar nenhuma URL para os bancos do outro aplicativo.
O fallback existente por `WEDDING_PHOTOS_DATABASE_PASSWORD` permanece disponível,
mas as URLs completas são a opção recomendada para este QA.

Não versionar `.env`, chaves ou credenciais em texto claro. O arquivo
`config/credentials.yml.enc` é criptografado; sua chave deve permanecer fora do Git.

## Armazenamento

O serviço `qa_disk` usa Disk do Active Storage e o caminho fornecido por
`ACTIVE_STORAGE_ROOT`, sem path fixo no código. O DigitalOcean Block Storage
Volume deverá estar montado e acessível antes de iniciar a aplicação; criação,
mount, fstab e permissões serão tratados fora desta tarefa.

Development continua em `local` e test em `test`, sem exigir variáveis de QA.
O serviço `s3_compatible` permanece disponível, conforme `docs/storage.md`.
Trocar o serviço não migra arquivos existentes automaticamente.

## Processos e recursos

O Droplet tem 1 GB de RAM, 1 GB de swap e outro Rails em execução. Começar com
uma instância web deste aplicativo e poucos threads; acompanhar memória antes
de aumentar concorrência. Não há garantia de capacidade para os dois apps.

O processo web poderá ser gerenciado pelo Passenger existente, ou por Puma
se isso for decidido na configuração futura. Puma mantém seu padrão atual de
3 threads, ajustável por ENV, sem adicionar workers nesta tarefa.

Será necessário executar separadamente `RAILS_ENV=production bin/jobs` para
Solid Queue, incluindo os jobs nativos de purge do Active Storage. O arquivo
`queue.yml` atual tem um processo worker por padrão, três threads e dispatcher.
Deixar `SOLID_QUEUE_IN_PUMA` ausente ao usar o processo separado; sua presença
ativa o plugin do Puma, mesmo que seu valor textual seja `false`.
Não iniciar jobs nesta preparação. Solid Cache usa o banco cache; Solid Cable
usa o banco cable, sem introduzir um processo dedicado adicional nesta tarefa.

## Comandos para a etapa futura

Com Ruby 4.0.5 selecionado, dependências instaladas e os quatro bancos vazios
previamente provisionados por quem administra o servidor:

```sh
RAILS_ENV=production bin/rails db:prepare
RAILS_ENV=production bin/rails assets:precompile
```

`db:prepare` inicializa também os schemas auxiliares Solid existentes. Se os
bancos não existirem, pode tentar criá-los; o provisionamento não faz parte desta
tarefa. Em atualizações, `db:migrate` aplica as migrations pendentes.

Para validar apenas a compilação local, sem chave de produção:

```sh
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

`SECRET_KEY_BASE_DUMMY` é exclusivo da compilação, nunca do runtime.

## Health check

`GET /up` usa `Rails::HealthController`, sem autenticação. Indica que Rails
inicializou; não verifica conectividade com banco, jobs ou volume.
`force_ssl` e `assume_ssl` foram preservados: o proxy e HTTPS deverão ser
configurados na etapa futura. Nenhuma configuração de Nginx, Passenger,
DNS, certificados ou deploy foi realizada aqui.
