from typing import Annotated
from json import dumps
from fastapi import Depends, APIRouter
from sqlalchemy import text
from sqlalchemy.ext.asyncio.session import AsyncSession
from service.interfaces.schemas import GraphQLRequest
from service.adapters.postgres import get_graphql_session


router = APIRouter(prefix="/graphql")


@router.post("")
async def grapqhl_request(
    body: GraphQLRequest, session: Annotated[AsyncSession, Depends(get_graphql_session)]
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
