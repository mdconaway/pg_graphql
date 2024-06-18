from typing import Annotated
from json import dumps
from logging import getLogger
from fastapi import Depends, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from fastapi_offline import FastAPIOffline
from sqlalchemy import text
from sqlalchemy.ext.asyncio.session import AsyncSession
from service.interfaces.schemas import GraphQLRequest
from service.middleware.requestlogger import RequestLogger
from service.adapters.postgres import postgresql
from service.config.general import general

logger = getLogger(__name__)

app = FastAPIOffline(
    title=general.PROJECT_NAME,
    version=general.API_VERSION,
    root_path=general.MOUNT_PATH,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestLogger)

router = APIRouter(prefix="/graphql")


async def get_session():
    async with postgresql.getSession() as session:
        yield session


@router.post("")
async def grapqhl_request(
    body: GraphQLRequest, session: Annotated[AsyncSession, Depends(get_session)]
):
    query = body.query
    operationName = body.operationName if body.operationName else None
    variables = f"{dumps(body.variables)}" if body.variables else None
    extensions = f"{dumps(body.extensions)}" if body.extensions else None
    result = await session.execute(
        text(
            f"""
            select(
                graphql.resolve(
                    (:query){'::text' if query else ''},
                    (:variables){'::jsonb' if variables else ''},
                    (:opname){'::text' if operationName else ''},
                    (:extensions){'::jsonb' if extensions else ''}
                )
            );
        """
        ).bindparams(
            opname=operationName,
            query=query,
            variables=variables,
            extensions=extensions,
        )
    )
    return result.scalar_one_or_none()


app.include_router(router)
