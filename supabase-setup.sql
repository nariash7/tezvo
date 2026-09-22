-- Ejecuta este archivo una sola vez en Supabase > SQL Editor.
-- Después crea los administradores desde Authentication > Users.

create extension if not exists pgcrypto;

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.store_settings (
  id integer primary key default 1 check (id = 1),
  store_name text not null default 'TEZVO',
  whatsapp text not null default '51933320033',
  hero_title text not null default 'Tecnología para tu día.',
  hero_text text not null default 'Descubre audífonos, cargadores, cables y accesorios. Consulta disponibilidad directamente por WhatsApp.',
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('audifonos','cargadores','cables','accesorios')),
  specs text not null default '',
  price numeric(12,2) not null default 0 check (price >= 0),
  badge text not null default '',
  image_url text not null default '',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.store_settings (id) values (1)
on conflict (id) do nothing;

insert into public.products (name, category, specs, price, badge, image_url, sort_order)
select * from (values
  ('Audífonos Air Lite','audifonos','Bluetooth · Estuche de carga · Micrófono',89,'Más vendido','assets/earbuds-white.png',1),
  ('Audífonos Air Black','audifonos','Bluetooth · Control táctil · Sonido estéreo',99,'Nuevo','assets/earbuds-black.png',2),
  ('Audífonos Air Blue','audifonos','Bluetooth · Estuche compacto · Micrófono',95,'Color especial','assets/earbuds-blue.png',3),
  ('Cargador rápido 20W','cargadores','USB-C · Carga rápida · Diseño compacto',65,'Recomendado','assets/charger-white.png',4),
  ('Cable USB-C reforzado','cables','Trenzado · Carga rápida · 1 metro',39,'Resistente','assets/charger-black.png',5),
  ('Kit de carga USB-C','accesorios','Adaptador + cable · Listo para usar',89,'Kit completo','assets/charger-white.png',6)
) as seed(name, category, specs, price, badge, image_url, sort_order)
where not exists (select 1 from public.products);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(select 1 from public.admins where user_id = auth.uid());
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

alter table public.admins enable row level security;
alter table public.store_settings enable row level security;
alter table public.products enable row level security;

drop policy if exists "admin puede verse" on public.admins;
create policy "admin puede verse" on public.admins
for select to authenticated using (user_id = auth.uid());

drop policy if exists "catalogo publico" on public.products;
create policy "catalogo publico" on public.products
for select to anon, authenticated using (active = true);

drop policy if exists "admin ve todos los productos" on public.products;
create policy "admin ve todos los productos" on public.products
for select to authenticated using (public.is_admin());

drop policy if exists "admin crea productos" on public.products;
create policy "admin crea productos" on public.products
for insert to authenticated with check (public.is_admin());

drop policy if exists "admin actualiza productos" on public.products;
create policy "admin actualiza productos" on public.products
for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin elimina productos" on public.products;
create policy "admin elimina productos" on public.products
for delete to authenticated using (public.is_admin());

drop policy if exists "ajustes publicos" on public.store_settings;
create policy "ajustes publicos" on public.store_settings
for select to anon, authenticated using (true);

drop policy if exists "admin actualiza ajustes" on public.store_settings;
create policy "admin actualiza ajustes" on public.store_settings
for update to authenticated using (public.is_admin()) with check (public.is_admin());

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

drop policy if exists "imagenes publicas" on storage.objects;
create policy "imagenes publicas" on storage.objects
for select to public using (bucket_id = 'product-images');

drop policy if exists "admin sube imagenes" on storage.objects;
create policy "admin sube imagenes" on storage.objects
for insert to authenticated with check (bucket_id = 'product-images' and public.is_admin());

drop policy if exists "admin actualiza imagenes" on storage.objects;
create policy "admin actualiza imagenes" on storage.objects
for update to authenticated using (bucket_id = 'product-images' and public.is_admin());

drop policy if exists "admin elimina imagenes" on storage.objects;
create policy "admin elimina imagenes" on storage.objects
for delete to authenticated using (bucket_id = 'product-images' and public.is_admin());

-- Para autorizar un administrador, reemplaza el UUID y ejecuta esta línea:
-- insert into public.admins (user_id) values ('UUID_DEL_USUARIO');
