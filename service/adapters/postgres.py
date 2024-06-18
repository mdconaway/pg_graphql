from __future__ import annotations
from typing import AsyncIterator
from contextlib import asynccontextmanager
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncEngine, async_sessionmaker
from sqlalchemy.ext.asyncio.session import AsyncSession
from service.config.adapters import adapters


if adapters.DATABASE_URI is None:
    raise TypeError("Postgres database URI is not defined")


# -------------------------------------------------------------------------------------------
# BASE ADAPTER
# -------------------------------------------------------------------------------------------
class PostgresqlAdapter:
    engine: AsyncEngine
    connection_uri: str
    engine: AsyncEngine

    def __init__(
        self, connection_uri="", pool_size=4, max_overflow=64, echo=True, **kwargs
    ):
        self.connection_uri = connection_uri
        self.engine = create_async_engine(
            self.connection_uri,
            echo=echo,
            future=True,
            pool_size=pool_size,
            max_overflow=max_overflow,
            **kwargs,
        )

    async def __call__(self) -> AsyncIterator[AsyncSession]:
        # Used by FastAPI Depends
        async with self.getSession() as session:
            yield session

    def asyncSessionGenerator(self):
        return async_sessionmaker(
            bind=self.engine,
            class_=AsyncSession,
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
        )

    @asynccontextmanager
    async def getSession(self):
        asyncSession = self.asyncSessionGenerator()
        async with asyncSession() as session:
            try:
                yield session
                await session.commit()
                await session.close()
            except:
                try:
                    await session.rollback()
                except:
                    pass
                await session.close()
                raise
            else:
                await session.close()

    async def addPostgresqlExtension(self) -> None:
        query = text("CREATE EXTENSION IF NOT EXISTS pg_trgm")
        async with self.getSession() as session:
            await session.execute(query)


postgresql = PostgresqlAdapter(
    connection_uri=adapters.DATABASE_URI,
    pool_size=adapters.DATABASE_POOL_SIZE,
    max_overflow=adapters.DATABASE_MAX_OVERFLOW,
    pool_pre_ping=True,
    echo=adapters.DATABASE_ECHO,
)


# This will force an app_user into all of the various table policies
async def get_graphql_user_session():
    async with postgresql.getSession() as session:
        await session.execute(text(f"SET ROLE {adapters.DATABASE_ROLE};"))
        try:
            yield session
        except:
            raise
        finally:
            await session.execute(text(f"RESET ROLE;"))
            await session.execute(text(f"RESET ALL;"))


# This will allow the server to do WHATEVER IT WANTS with the database. BE CAREFUL
async def get_graphql_admin_session():
    async with postgresql.getSession() as session:
        yield session
