-- BLK · Metas de Materiais — banco de dados (Supabase / PostgreSQL)
-- Cole este arquivo inteiro no SQL Editor do Supabase e clique em Run.
-- Pode rodar de novo sem problema: ele não apaga dados.

-- ============================================================
-- 1. Tabelas
-- ============================================================

-- Uma linha por pessoa que entrou com o Discord.
-- papel: 'pendente' (aguardando aprovação), 'membro' ou 'lider'.
create table if not exists public.membros (
  id           uuid primary key references auth.users (id) on delete cascade,
  discord_id   text,
  discord_nome text,
  avatar_url   text,
  nome         text,   -- nome do personagem no jogo
  game_id      text,   -- ID do personagem no jogo
  papel        text not null default 'pendente' check (papel in ('pendente', 'membro', 'lider')),
  criado_em    timestamptz not null default now()
);

-- Dois membros não podem ter o mesmo ID no jogo.
create unique index if not exists membros_game_id_unico
  on public.membros (lower(game_id)) where game_id is not null;

-- Uma única linha de configuração (id = 1).
create table if not exists public.config (
  id            int primary key default 1 check (id = 1),
  rotas         int not null default 5 check (rotas between 1 and 100),
  blips         int not null default 23,
  por_rota      jsonb not null,   -- quanto cada material rende em uma rota
  valores       jsonb not null,   -- quanto paga cada meta batida
  exemplo       boolean not null default true,  -- true enquanto os valores são de exemplo
  atualizado_em timestamptz not null default now()
);

-- Valores de EXEMPLO. Um líder deve ajustar na aba "Metas e valores".
insert into public.config (id, rotas, blips, por_rota, valores, exemplo)
values (
  1, 5, 23,
  '{"plastico":84,"massa":72,"moeda":254,"ferro":90,"tecido":97,"borracha":105}',
  '{"plastico":1000,"massa":1000,"moeda":1000,"ferro":1000,"tecido":1000,"borracha":1000}',
  true
)
on conflict (id) do nothing;

-- Cada lançamento de material. A semana é definida pelo servidor (segunda a domingo, horário de Brasília).
create table if not exists public.registros (
  id         bigint generated always as identity primary key,
  membro_id  uuid not null default auth.uid() references public.membros (id) on delete cascade,
  semana     date not null default (date_trunc('week', now() at time zone 'America/Sao_Paulo'))::date,
  material   text not null check (material in ('plastico', 'massa', 'moeda', 'ferro', 'tecido', 'borracha')),
  qtd        int  not null check (qtd between 1 and 100000),
  criado_em  timestamptz not null default now()
);
create index if not exists registros_semana_membro on public.registros (semana, membro_id);

-- Pagamentos marcados pelos líderes. O valor fica gravado como foi pago.
create table if not exists public.pagamentos (
  id        bigint generated always as identity primary key,
  semana    date not null,
  membro_id uuid not null references public.membros (id) on delete cascade,
  valor     int  not null check (valor >= 0),
  pago_em   timestamptz not null default now(),
  pago_por  uuid default auth.uid() references public.membros (id) on delete set null,
  unique (semana, membro_id)
);

-- ============================================================
-- 2. Funções auxiliares
-- ============================================================

create or replace function public.papel_atual()
returns text language sql stable security definer set search_path = public as $$
  select papel from public.membros where id = auth.uid()
$$;

create or replace function public.eh_membro()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.papel_atual() in ('membro', 'lider'), false)
$$;

create or replace function public.eh_lider()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.papel_atual() = 'lider', false)
$$;

create or replace function public.semana_atual()
returns date language sql stable as $$
  select (date_trunc('week', now() at time zone 'America/Sao_Paulo'))::date
$$;

-- Quando alguém entra pela primeira vez com o Discord, cria o perfil como 'pendente'.
create or replace function public.novo_usuario()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.membros (id, discord_id, discord_nome, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'provider_id', new.raw_user_meta_data ->> 'sub'),
    coalesce(
      new.raw_user_meta_data -> 'custom_claims' ->> 'global_name',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      'Sem nome'
    ),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario
  after insert on auth.users
  for each row execute function public.novo_usuario();

-- Cria o perfil de quem já tinha entrado antes de este SQL rodar (não faz nada se não houver ninguém).
insert into public.membros (id, discord_id, discord_nome, avatar_url)
select u.id,
       coalesce(u.raw_user_meta_data ->> 'provider_id', u.raw_user_meta_data ->> 'sub'),
       coalesce(u.raw_user_meta_data -> 'custom_claims' ->> 'global_name',
                u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', 'Sem nome'),
       u.raw_user_meta_data ->> 'avatar_url'
from auth.users u
on conflict (id) do nothing;

-- ============================================================
-- 3. Ações que mexem em cadastro e acesso (só por estas funções)
-- ============================================================

-- Salva nome e ID no jogo. Cada um salva o próprio; líderes salvam de qualquer pessoa.
create or replace function public.salvar_cadastro(p_alvo uuid, p_nome text, p_game_id text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_nome text := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_id   text := btrim(coalesce(p_game_id, ''));
begin
  if auth.uid() is null then
    raise exception 'Entre com o Discord primeiro.';
  end if;
  if p_alvo <> auth.uid() and not public.eh_lider() then
    raise exception 'Somente líderes editam o cadastro de outra pessoa.';
  end if;
  if char_length(v_nome) < 2 or char_length(v_nome) > 40 then
    raise exception 'O nome deve ter de 2 a 40 caracteres.';
  end if;
  if v_id !~ '^[0-9A-Za-z]{1,12}$' then
    raise exception 'O ID deve ter até 12 letras ou números, sem espaços.';
  end if;
  update public.membros set nome = v_nome, game_id = v_id where id = p_alvo;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;
exception
  when unique_violation then
    raise exception 'Esse ID já está cadastrado para outra pessoa.';
end;
$$;

-- Aprova, promove ou revoga o acesso de alguém. Só líderes.
create or replace function public.definir_papel(p_alvo uuid, p_papel text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.eh_lider() then
    raise exception 'Somente líderes alteram o acesso.';
  end if;
  if p_papel not in ('pendente', 'membro', 'lider') then
    raise exception 'Papel inválido.';
  end if;
  if p_alvo = auth.uid() and p_papel <> 'lider' then
    raise exception 'Você não pode tirar a própria liderança.';
  end if;
  update public.membros set papel = p_papel where id = p_alvo;
end;
$$;

revoke execute on function public.salvar_cadastro(uuid, text, text) from public, anon;
revoke execute on function public.definir_papel(uuid, text) from public, anon;
grant  execute on function public.salvar_cadastro(uuid, text, text) to authenticated;
grant  execute on function public.definir_papel(uuid, text) to authenticated;

-- ============================================================
-- 4. Permissões (RLS): quem pode ler e escrever o quê
-- ============================================================

alter table public.membros    enable row level security;
alter table public.config     enable row level security;
alter table public.registros  enable row level security;
alter table public.pagamentos enable row level security;

-- Visitantes sem login não enxergam nada.
revoke all on public.membros, public.config, public.registros, public.pagamentos from anon;

-- membros: cada um vê o próprio perfil; membros e líderes veem todos. Ninguém escreve direto.
revoke insert, update, delete on public.membros from authenticated;
drop policy if exists membros_ler on public.membros;
create policy membros_ler on public.membros for select to authenticated
  using (id = auth.uid() or public.eh_membro());

-- config: membros leem, líderes alteram.
drop policy if exists config_ler on public.config;
create policy config_ler on public.config for select to authenticated
  using (public.eh_membro());
drop policy if exists config_gravar on public.config;
create policy config_gravar on public.config for all to authenticated
  using (public.eh_lider()) with check (public.eh_lider());

-- registros: membros leem todos, lançam só no próprio nome e só na semana atual.
-- Podem apagar o próprio lançamento da semana atual; líderes apagam qualquer um da semana atual.
drop policy if exists registros_ler on public.registros;
create policy registros_ler on public.registros for select to authenticated
  using (public.eh_membro());
drop policy if exists registros_inserir on public.registros;
create policy registros_inserir on public.registros for insert to authenticated
  with check (public.eh_membro() and membro_id = auth.uid() and semana = public.semana_atual());
drop policy if exists registros_apagar on public.registros;
create policy registros_apagar on public.registros for delete to authenticated
  using (public.eh_membro() and (membro_id = auth.uid() or public.eh_lider()) and semana = public.semana_atual());
revoke update on public.registros from authenticated;

-- pagamentos: membros leem, só líderes marcam e desfazem.
drop policy if exists pagamentos_ler on public.pagamentos;
create policy pagamentos_ler on public.pagamentos for select to authenticated
  using (public.eh_membro());
drop policy if exists pagamentos_gravar on public.pagamentos;
create policy pagamentos_gravar on public.pagamentos for all to authenticated
  using (public.eh_lider()) with check (public.eh_lider());

-- ============================================================
-- 5. Primeiro líder
-- ============================================================
-- Depois de entrar uma vez com o seu Discord no site, rode UMA vez:
--
--   update public.membros set papel = 'lider' where discord_nome = 'SEU NOME NO DISCORD';
--
-- (use o nome que aparece em: select id, discord_nome, discord_id from public.membros;)
-- Os outros líderes você promove pela própria página, na aba Membros.
