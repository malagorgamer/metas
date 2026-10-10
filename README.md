# BLK · Metas de Materiais

Página para os membros da BLK registrarem os materiais da semana, com relatório para os líderes e controle de pagamento das metas batidas.

- **Página:** hospedada no GitHub Pages (gratuito).
- **Banco de dados e login:** Supabase (gratuito), com login pelo Discord.
- **Quem entra:** qualquer pessoa pode entrar com o Discord, mas só registra depois que um líder aprova.

## O que tem na pasta

| Arquivo | Para que serve |
|---|---|
| `index.html` | A página inteira |
| `config.js` | Onde você cola os dados do seu Supabase (passo 5) |
| `supabase.sql` | Cria o banco de dados e as regras de segurança (passo 2) |
| `icons/` | Os ícones dos 6 materiais |

## Passo a passo

Reserve uns 20 a 30 minutos. Faça na ordem.

### 1. Criar o projeto no Supabase

1. Entre em https://supabase.com e crie uma conta (pode usar o GitHub).
2. Clique em **New project**. Dê o nome `blk-metas`, crie uma senha do banco (guarde) e escolha a região **South America (São Paulo)**.
3. Espere uns 2 minutos até o projeto ficar pronto.

### 2. Criar o banco de dados

1. No menu da esquerda, abra **SQL Editor** e clique em **New query**.
2. Abra o arquivo `supabase.sql`, copie **tudo** e cole no editor.
3. Clique em **Run**. Deve aparecer "Success". Pode rodar de novo sem problema, ele não apaga dados.

### 3. Criar o aplicativo no Discord

1. Entre em https://discord.com/developers/applications e clique em **New Application**. Nome: `BLK Metas`.
2. No menu da esquerda, abra **OAuth2**.
3. Copie o **Client ID**. Clique em **Reset Secret** e copie o **Client Secret** (ele só aparece uma vez).
4. Deixe essa aba aberta. No próximo passo você vai precisar colar um endereço nela.

### 4. Ligar o Discord ao Supabase

1. No Supabase, abra **Authentication**, depois **Providers** (ou **Sign In / Providers**) e clique em **Discord**.
2. Ligue a opção **Enable**, cole o **Client ID** e o **Client Secret**.
3. Nessa mesma tela o Supabase mostra um endereço chamado **Callback URL (for OAuth)**, parecido com `https://xxxxxxxx.supabase.co/auth/v1/callback`. Copie.
4. Volte na aba do Discord, em **OAuth2 > Redirects**, clique em **Add Redirect**, cole esse endereço e clique em **Save Changes**.
5. De volta ao Supabase, clique em **Save**.

### 5. Colocar os dados do Supabase no `config.js`

1. No Supabase, abra **Project Settings** (a engrenagem), depois **API**.
2. Copie o **Project URL** e a chave **anon public**.
3. Abra o arquivo `config.js` e troque os dois textos `COLE_AQUI...` por esses valores, mantendo as aspas:

```js
window.BLK_CONFIG = {
  SUPABASE_URL: "https://xxxxxxxx.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOi..."
};
```

A chave `anon public` pode ficar no GitHub: quem protege os dados são as regras do `supabase.sql`. **Nunca** use a chave `service_role` aqui.

### 6. Publicar no GitHub Pages

1. Em https://github.com, crie um repositório novo (por exemplo `blk-metas`). Pode ser público.
2. Clique em **Add file > Upload files** e envie **todos os arquivos e a pasta `icons`** (inclusive o `config.js` já preenchido).
3. Abra **Settings > Pages**. Em **Source**, escolha **Deploy from a branch**, branch **main** e pasta **/ (root)**. Clique em **Save**.
4. Em 1 ou 2 minutos o endereço aparece no topo da página: `https://SEU-USUARIO.github.io/blk-metas/`.

### 7. Liberar o endereço no Supabase

1. No Supabase, abra **Authentication > URL Configuration**.
2. Em **Site URL**, cole o endereço do GitHub Pages: `https://SEU-USUARIO.github.io/blk-metas/`.
3. Em **Redirect URLs**, clique em **Add URL** e cole `https://SEU-USUARIO.github.io/blk-metas/**` (com os dois asteriscos no final). Salve.

Sem esse passo, o login com o Discord volta para o endereço errado.

### 8. Criar o primeiro líder

1. Abra o endereço do site e clique em **Entrar com Discord**. Autorize.
2. Você vai ver "aguardando aprovação". É normal: ninguém é líder ainda.
3. No Supabase, abra o **SQL Editor** e rode (trocando pelo seu nome do Discord, exatamente como aparece no canto da página):

```sql
update public.membros set papel = 'lider' where discord_nome = 'SEU NOME NO DISCORD';
```

Se não souber o nome certo, rode `select id, discord_nome, discord_id from public.membros;` e veja a lista.

4. Atualize a página. Agora você é líder e vê as quatro abas.

### 9. Ajustar as metas

Na aba **Metas e valores**, confira:

- **Rotas por semana:** quantas rotas de 23 blips cada membro deve fazer.
- **Por rota:** quanto cada material rende em uma rota (já vêm 84, 72, 254, 90, 97 e 105).
- **Valor da meta:** quanto paga cada meta batida.

Os valores que vêm prontos são **de exemplo** (5 rotas e $ 1.000 por meta). Enquanto um líder não salvar, a página mostra um aviso.

## Uso no dia a dia

- **Membro novo:** entra com o Discord, cadastra nome e ID na aba **Membros** e espera aprovação. Um líder vê "Membros (1 novo)" e clica em **Aprovar**.
- **Registrar:** cada membro lança as quantidades na aba **Registrar**. Pode desfazer um lançamento errado enquanto a semana não fecha.
- **Semana:** vai de segunda 00:00 a domingo 23:59 (horário de Brasília). Depois que fecha, ninguém mais altera aquela semana.
- **Relatório:** os líderes abrem **Relatório da semana**, conferem o que cada um fez, pagam no jogo e clicam em **Marcar como pago**. O valor pago fica gravado mesmo que as metas mudem depois.
- **Discord:** o botão **Copiar relatório para o Discord** gera o texto pronto para colar no canal dos líderes.
- **Promover ou revogar:** na aba **Membros**, os líderes podem tornar alguém líder, tirar a liderança ou revogar o acesso.

## Quem pode o quê

| Ação | Pendente | Membro | Líder |
|---|---|---|---|
| Cadastrar o próprio nome e ID | sim | sim | sim |
| Ver relatório e lista de membros | não | sim | sim |
| Registrar materiais (só no próprio nome) | não | sim | sim |
| Desfazer o próprio registro (semana atual) | não | sim | sim |
| Marcar e desfazer pagamentos | não | não | sim |
| Mudar metas e valores | não | não | sim |
| Aprovar, promover, revogar, editar cadastro de outros | não | não | sim |

Essas regras ficam no próprio banco, então valem mesmo que alguém tente burlar a página.

## Backup e cuidados

- **Backup:** no Supabase, abra **Table Editor**, escolha a tabela (`registros`, `pagamentos`, `membros`) e use **Export** para baixar em CSV. Vale fazer isso de vez em quando.
- **Plano gratuito:** o Supabase pode pausar projetos gratuitos que ficam um tempo sem uso. Como o grupo usa toda semana, em geral não acontece, mas confira as regras atuais no site deles. Se pausar, o botão de restaurar fica no painel.
- **Quem tem o link:** qualquer pessoa com Discord consegue pedir acesso, mas não vê nada nem registra até um líder aprovar.
- **Conta do Supabase:** quem administra o projeto no Supabase enxerga todos os dados. Use uma conta de confiança e ative a verificação em duas etapas.

## Se algo der errado

| Sintoma | O que fazer |
|---|---|
| "Falta configurar o Supabase" | Preencha o `config.js` (passo 5) e envie de novo ao GitHub |
| O login volta para um endereço errado | Confira o passo 7 |
| Erro `redirect_uri` no Discord | Confira o passo 4, item 4: o endereço do callback precisa estar igual nos dois lados |
| "Seu perfil ainda não existe no banco" | Rode o `supabase.sql` de novo (passo 2) e entre de novo |
| A página não atualiza depois de enviar arquivos | Espere 1 a 2 minutos e recarregue com Ctrl+F5 |
