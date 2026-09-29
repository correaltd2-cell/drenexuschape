-- Cole tudo no SQL Editor do Supabase e clique em Run. Pode rodar de novo sem problema.

-- 1. Quem pode entrar no app e o que pode fazer
--    editor: importa DRE, lança indicadores manuais e salva comparativos
--    leitor: só visualiza
create table if not exists public.perfis (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nome text,
  papel text not null default 'leitor' check (papel in ('editor', 'leitor'))
);

-- 2. Relatórios do ELLO: um por mês e tipo (venc = vencimentos/previsto, pag = pagamentos/realizado)
--    Guarda só os totais por conta, nunca os lançamentos com nomes de alunos.
create table if not exists public.relatorios (
  mes text not null check (mes ~ '^\d{4}-\d{2}$'),
  tipo text not null check (tipo in ('venc', 'pag')),
  dados jsonb not null,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid default auth.uid() references auth.users(id),
  primary key (mes, tipo)
);

-- 3. Indicadores manuais (alunos, leads, satisfação, Instagram), um registro por mês
create table if not exists public.manuais (
  mes text primary key check (mes ~ '^\d{4}-\d{2}$'),
  dados jsonb not null default '{}',
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid default auth.uid() references auth.users(id)
);

-- 4. Comparativos salvos com nome, visíveis para todos
create table if not exists public.comparativos (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  cfg jsonb not null,
  criado_em timestamptz not null default now(),
  criado_por uuid default auth.uid() references auth.users(id)
);

-- Funções de permissão
create or replace function public.tem_acesso() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfis where user_id = auth.uid())
$$;

create or replace function public.e_editor() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfis where user_id = auth.uid() and papel = 'editor')
$$;

-- Segurança: sem login e sem perfil, nada é lido nem gravado
alter table public.perfis enable row level security;
alter table public.relatorios enable row level security;
alter table public.manuais enable row level security;
alter table public.comparativos enable row level security;

drop policy if exists "ver o próprio perfil" on public.perfis;
create policy "ver o próprio perfil" on public.perfis
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "ler relatórios" on public.relatorios;
create policy "ler relatórios" on public.relatorios for select to authenticated using (public.tem_acesso());
drop policy if exists "incluir relatórios" on public.relatorios;
create policy "incluir relatórios" on public.relatorios for insert to authenticated with check (public.e_editor());
drop policy if exists "alterar relatórios" on public.relatorios;
create policy "alterar relatórios" on public.relatorios for update to authenticated using (public.e_editor()) with check (public.e_editor());
drop policy if exists "apagar relatórios" on public.relatorios;
create policy "apagar relatórios" on public.relatorios for delete to authenticated using (public.e_editor());

drop policy if exists "ler manuais" on public.manuais;
create policy "ler manuais" on public.manuais for select to authenticated using (public.tem_acesso());
drop policy if exists "incluir manuais" on public.manuais;
create policy "incluir manuais" on public.manuais for insert to authenticated with check (public.e_editor());
drop policy if exists "alterar manuais" on public.manuais;
create policy "alterar manuais" on public.manuais for update to authenticated using (public.e_editor()) with check (public.e_editor());
drop policy if exists "apagar manuais" on public.manuais;
create policy "apagar manuais" on public.manuais for delete to authenticated using (public.e_editor());

drop policy if exists "ler comparativos" on public.comparativos;
create policy "ler comparativos" on public.comparativos for select to authenticated using (public.tem_acesso());
drop policy if exists "incluir comparativos" on public.comparativos;
create policy "incluir comparativos" on public.comparativos for insert to authenticated with check (public.e_editor());
drop policy if exists "alterar comparativos" on public.comparativos;
create policy "alterar comparativos" on public.comparativos for update to authenticated using (public.e_editor()) with check (public.e_editor());
drop policy if exists "apagar comparativos" on public.comparativos;
create policy "apagar comparativos" on public.comparativos for delete to authenticated using (public.e_editor());


-- ============================================================
-- DEPOIS de criar os usuários em Authentication > Users, rode
-- uma linha destas para cada pessoa, trocando o e-mail e o nome:
--
-- insert into public.perfis (user_id, nome, papel)
-- select id, 'Jaziel', 'editor' from auth.users where email = 'email.do.jaziel@exemplo.com';
--
-- insert into public.perfis (user_id, nome, papel)
-- select id, 'Nome', 'leitor' from auth.users where email = 'outra.pessoa@exemplo.com';
-- ============================================================
