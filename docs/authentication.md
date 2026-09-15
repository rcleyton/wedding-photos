# Acesso administrativo

O projeto usa a autenticação nativa gerada pelo Rails 8, com senha protegida por
`bcrypt`, sessões persistidas no banco e cookie assinado. Não há cadastro público.

Para criar o usuário inicial em desenvolvimento, execute `bin/rails console`:

```ruby
require "io/console"
print "Email: "
email = STDIN.gets.strip
password = STDIN.getpass("Senha: ")
User.create!(email_address: email, password: password)
password = nil
```

A senha é solicitada sem eco e não fica escrita no histórico do console.
Nenhuma credencial padrão é criada ou versionada.

Acesse `/events/:id` ou `/events/:id/qr_code`: após o login com `email_address`
e `password`, a aplicação retorna ao endereço solicitado. O login também está
disponível em `/session/new`; o botão **Sair** encerra a sessão.

As rotas `/e/:public_token` e `/e/:public_token/photos` continuam públicas.
O QR Code aponta para essa página pública; convidados podem escaneá-lo e enviar
fotos sem login. Apenas a página administrativa que gera/exibe o QR é protegida.
