create extension if not exists postgis;
create extension if not exists pg_graphql;

-- Default role / privileges
create role anon;

grant usage on schema public to anon;
alter default privileges in schema public grant all on tables to anon;
alter default privileges in schema public grant all on functions to anon;
alter default privileges in schema public grant all on sequences to anon;

grant usage on schema graphql to anon;
grant all on function graphql.resolve to anon;

alter default privileges in schema graphql grant all on tables to anon;
alter default privileges in schema graphql grant all on functions to anon;
alter default privileges in schema graphql grant all on sequences to anon;
-- End Default role / privileges

-- Global Types
-- UUID v7
create extension if not exists pgcrypto;
create or replace function
  uuid_generate_v7()
returns
  uuid
language
  plpgsql
parallel safe
as $$
  declare
    -- The current UNIX timestamp in milliseconds
    unix_time_ms CONSTANT bytea not null default substring(int8send((extract(epoch FROM clock_timestamp()) * 1000)::bigint) from 3);
    -- The buffer used to create the UUID, starting with the UNIX timestamp and followed by random bytes
    buffer                bytea not null default unix_time_ms || gen_random_bytes(10);
  begin
    -- Set most significant 4 bits of 7th byte to 7 (for UUID v7), keeping the last 4 bits unchanged
    buffer = set_byte(buffer, 6, (b'0111' || get_byte(buffer, 6)::bit(4))::bit(8)::int);
    -- Set most significant 2 bits of 9th byte to 2 (the UUID variant specified in RFC 4122), keeping the last 6 bits unchanged
    buffer = set_byte(buffer, 8, (b'10'   || get_byte(buffer, 8)::bit(6))::bit(8)::int);
    return encode(buffer, 'hex');
  end
$$
;
-- Email & Validator
create extension if not exists citext;
create domain emailaddr as citext
  check ( value ~ '^[a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$' );
-- Geography, SRID 4326 with GEOJSON default representation
-- create domain json_geography as GEOGRAPHY(geometry, 4326);
create or replace function json(geography) returns json as $$
  select ST_AsGeoJson($1)::json;
$$ language sql immutable;
create cast (geography AS json) with function json(geography) as implicit;

create or replace function geography(json) RETURNS geography AS $$
  -- here we reuse the previous app_uuid(text) function
  select ST_GeomFromGeoJSON($1::text)::geography;
$$ language sql immutable;
CREATE CAST (json AS geography) WITH FUNCTION geography(json) AS IMPLICIT;
-- End Global Types

-- GraphQL Entrypoint
create function graphql(
    "operationName" text default null,
    query text default null,
    variables jsonb default null,
    extensions jsonb default null
)
    returns jsonb
    language sql
as $$
    select graphql.resolve(
        query := query,
        variables := coalesce(variables, '{}'),
        "operationName" := "operationName",
        extensions := extensions
    );
$$;
-- End GraphQL Entrypoint

-- Global Settings
comment on schema public is '@graphql({"inflect_names": true, "max_rows": 100})';
-- End Global Settings

-- ACCOUNTS
-- Accounts Model
create table account(
    id uuid not null default uuid_generate_v7() primary key,
    email emailaddr not null unique,
    created_at timestamp with time zone not null default (timezone('utc', now()))
);
-- Accounts Config
comment on table public.account is e'@graphql({"totalCount": {"enabled": true}})';
-- Accounts Permissions
revoke all on table public.account from anon;
grant select(id), select(email), select(created_at), 
    insert(email), 
    update(email) 
    on public.account to anon;
-- End ACCOUNTS


-- BLOGS
-- Blog Model
create table blog(
    id uuid not null default uuid_generate_v7() primary key,
    owner_id uuid not null references account(id) on delete cascade,
    name varchar(255) not null,
    description varchar(255),
    created_at timestamp with time zone not null default (timezone('utc', now()))
);
-- Blog Config
comment on table blog is e'@graphql({"totalCount": {"enabled": true}})';
-- Blog Permissions
revoke all on table blog from anon;
grant select(id), select(owner_id), select(name), select(description), select(created_at), 
    insert(owner_id), insert(name), insert(description), 
    update(name), update(description) 
    on blog to anon;
-- END BLOGS

-- BLOG POSTS
-- BlogPost Types
create type blog_post_status as enum ('PENDING', 'RELEASED');
-- BlogPost Model
-- geojson geometry generated always as (location::geometry) stored,
create table blog_post(
    id uuid not null default uuid_generate_v7() primary key,
    blog_id uuid not null references blog(id) on delete cascade,
    title varchar(255) not null,
    body varchar(10000),
    tags TEXT[],
    location GEOGRAPHY(geometry, 4326) not null default ST_GeographyFromText('POINT(0 0)'),
    status blog_post_status not null,
    created_at timestamp with time zone not null default (timezone('utc', now()))
);
create index idx_blog_post_location_gist on blog_post using gist(location);
-- BlogPost Config
comment on table blog_post is e'@graphql({"totalCount": {"enabled": true}})';
-- BlogPost Permissions
revoke all on table blog_post from anon;
grant select(id), select(blog_id), select(title), select(body), select(tags), select(location), select(status), select(created_at),
    insert(blog_id), insert(title), insert(body), insert(tags), insert(location), insert(status),
    update(title), update(body), update(tags), update(location), update(status)
    on blog_post to anon;
-- End BLOG POSTS


-- DEMO DATA BELOW
-- 5 Accounts
insert into public.account(email)
values
    ('aardvark@x.com'),
    ('bat@x.com'),
    ('cat@x.com'),
    ('dog@x.com'),
    ('elephant@x.com');

insert into blog(owner_id, name, description)
values
    ((select id from account where email ilike 'a%'), 'A: Blog 1', 'a desc1'),
    ((select id from account where email ilike 'a%'), 'A: Blog 2', 'a desc2'),
    ((select id from account where email ilike 'a%'), 'A: Blog 3', 'a desc3'),
    ((select id from account where email ilike 'b%'), 'B: Blog 3', 'b desc1');

insert into blog_post (blog_id, title, body, tags, status)
values
    ((SELECT id FROM blog WHERE name = 'A: Blog 1'), 'Post 1 in A Blog 1', 'Content for post 1 in A Blog 1', '{"tech", "update"}', 'RELEASED'),
    ((SELECT id FROM blog WHERE name = 'A: Blog 1'), 'Post 2 in A Blog 1', 'Content for post 2 in A Blog 1', '{"announcement", "tech"}', 'PENDING'),
    ((SELECT id FROM blog WHERE name = 'A: Blog 2'), 'Post 1 in A Blog 2', 'Content for post 1 in A Blog 2', '{"personal"}', 'RELEASED'),
    ((SELECT id FROM blog WHERE name = 'A: Blog 2'), 'Post 2 in A Blog 2', 'Content for post 2 in A Blog 2', '{"update"}', 'RELEASED'),
    ((SELECT id FROM blog WHERE name = 'A: Blog 3'), 'Post 1 in A Blog 3', 'Content for post 1 in A Blog 3', '{"travel", "adventure"}', 'PENDING'),
    ((SELECT id FROM blog WHERE name = 'B: Blog 3'), 'Post 1 in B Blog 3', 'Content for post 1 in B Blog 3', '{"tech", "review"}', 'RELEASED'),
    ((SELECT id FROM blog WHERE name = 'B: Blog 3'), 'Post 2 in B Blog 3', 'Content for post 2 in B Blog 3', '{"coding", "tutorial"}', 'PENDING');
