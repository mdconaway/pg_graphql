-- Activate extenions
-- These must always come first in your first-time db init!
create extension if not exists postgis;
create extension if not exists pg_graphql;
-- End Activate extension

-- Default role / privileges
create role app_user;

grant usage on schema public to app_user;
alter default privileges in schema public grant all on tables to app_user;
alter default privileges in schema public grant all on functions to app_user;
alter default privileges in schema public grant all on sequences to app_user;

grant usage on schema graphql to app_user;
grant all on function graphql.resolve to app_user;

alter default privileges in schema graphql grant all on tables to app_user;
alter default privileges in schema graphql grant all on functions to app_user;
alter default privileges in schema graphql grant all on sequences to app_user;
-- End Default role / privileges

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
-- json(geography) does all the implicit casting to RENDER geometry columns in Queries
create or replace function json(geography) returns json as $$
  select ($1::geometry)::json;
$$ language sql immutable;
create cast (geography AS json) with function json(geography) as implicit;
-- geography(json) WOULD implicitly convert incoming json values to geography types IF pg_graphql ever allows objects as input for JSON scalars
create or replace function geography(json) returns geography as $$
  select ST_GeomFromGeoJSON($1::json)::geography;
$$ language sql immutable;
create cast (json AS geography) with function geography(json) as implicit;
-- geography(text) currently converts incoming stringified json representations of a geography object during an incoming Mutation
create or replace function geography(text) returns geography as $$
  select ST_GeomFromGeoJSON($1::json)::geography;
$$ language sql immutable;
create cast (text AS geography) with function geography(text) as implicit;

-- update_at timestamp
create or replace function updated_at_stamp()
returns trigger as $$
begin
   new.updated_at = timezone('utc', now());
   return new;
end;
$$ language 'plpgsql';
-- End Global Types

-- Global Settings
comment on schema public is '@graphql({"inflect_names": true, "max_rows": 100})';
-- End Global Settings

-- ACCOUNTS
-- Accounts Model
create table account(
    id uuid not null default uuid_generate_v7() primary key,
    email emailaddr not null unique,
    created_at timestamp with time zone not null default (timezone('utc', now())),
    updated_at timestamp with time zone not null default (timezone('utc', now()))
);
-- Accounts Config
comment on table public.account is e'@graphql({"totalCount": {"enabled": true}})';
-- Accounts Triggers
create trigger account_updated_at_stamp before update
    on account for each row execute procedure
    updated_at_stamp();
-- Accounts Permissions
revoke all on table public.account from app_user;
grant select(id), select(email), select(created_at), select(updated_at),
    insert(email),
    update(email)
    on public.account to app_user;
-- End ACCOUNTS


-- BLOGS
-- Blog Model
create table blog(
    id uuid not null default uuid_generate_v7() primary key,
    owner_id uuid not null references account(id) on delete cascade,
    name varchar(255) not null,
    description varchar(255),
    created_at timestamp with time zone not null default (timezone('utc', now())),
    updated_at timestamp with time zone not null default (timezone('utc', now()))
);
-- Blog Config
comment on table blog is e'@graphql({"totalCount": {"enabled": true}})';
-- Blog Triggers
create trigger blog_updated_at_stamp before update
    on blog for each row execute procedure
    updated_at_stamp();
-- Blog Permissions
revoke all on table blog from app_user;
grant select(id), select(owner_id), select(name), select(description), select(created_at), select(updated_at),
    insert(owner_id), insert(name), insert(description),
    update(name), update(description)
    on blog to app_user;
-- END BLOGS

-- BLOG POSTS
-- BlogPost Types
create type blog_post_status as enum ('PENDING', 'RELEASED');
-- BlogPost Model
-- geojson geography generated always as (location::geography) stored,
create table blog_post(
    id uuid not null default uuid_generate_v7() primary key,
    blog_id uuid not null references blog(id) on delete cascade,
    title varchar(255) not null,
    body varchar(10000),
    tags TEXT[],
    location geometry(geometry, 4326) not null default ST_GeomFromGeoJSON(json_build_object('type', 'Point', 'coordinates', array[0,0])),
    status blog_post_status not null,
    created_at timestamp with time zone not null default (timezone('utc', now())),
    updated_at timestamp with time zone not null default (timezone('utc', now()))
);
create index idx_blog_post_location_gist on blog_post using gist(location);
-- BlogPost Config
comment on table blog_post is e'@graphql({"totalCount": {"enabled": true}})';
-- BlogPost Triggers
create trigger blog_post_updated_at_stamp before update
    on blog_post for each row execute procedure
    updated_at_stamp();
-- BlogPost Permissions
revoke all on table blog_post from app_user;
grant select(id), select(blog_id), select(title), select(body), select(tags), select(location), select(status), select(created_at), select(updated_at),
    insert(blog_id), insert(title), insert(body), insert(tags), insert(location), insert(status),
    update(title), update(body), update(tags), update(location), update(status)
    on blog_post to app_user;
-- End BLOG POSTS
-- You can create a blog_post with this graphql mutation payload:
-- {
--   "blogPosts":[
--     {
--       "body": "Content for New Post in A Blog 3",
--       "tags": [
--         "travel",
--         "adventure"
--       ],
--       "title": "New Post in A Blog 3",
--       "blogId": "0190269c-4f93-717d-9c74-3eabd6b9de7e",
--       "status": "PENDING",
--       "location": "{\"type\": \"Point\",\"coordinates\": [2,2]}"
--     }
--   ]
-- }


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
