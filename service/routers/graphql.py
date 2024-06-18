from typing import Any, Annotated
from json import dumps
from io import BytesIO
from fastapi import Request, Depends, APIRouter
from fastapi.responses import StreamingResponse
from graphql import get_introspection_query, build_client_schema, print_schema
from sqlalchemy import text
from sqlalchemy.ext.asyncio.session import AsyncSession
from service.interfaces.schemas import GraphQLRequest
from service.adapters.postgres import (
    get_graphql_user_session,
    get_graphql_admin_session,
)
from service.policies.become_first_account import become_first_account
from service.policies.dump_session_attributes import dump_session_attributes


router = APIRouter(prefix="/graphql")


@router.post("", dependencies=[Depends(become_first_account)])
async def grapqhl_request(
    request: Request,
    body: GraphQLRequest,
    session: Annotated[AsyncSession, Depends(get_graphql_user_session)],
):
    query = body.query
    operationName = body.operationName if body.operationName else None
    variables = f"{dumps(body.variables)}" if body.variables else None
    extensions = f"{dumps(body.extensions)}" if body.extensions else None
    # Session-like setup
    await dump_session_attributes(request=request, session=session)
    # End session-like setup
    result = await session.execute(
        text(
            f"""
            select graphql.resolve(
                (:query){'::text' if query else ''},
                (:variables){'::jsonb' if variables else ''},
                (:opname){'::text' if operationName else ''},
                (:extensions){'::jsonb' if extensions else ''}
            );
        """
        ).bindparams(
            opname=operationName,
            query=query,
            variables=variables,
            extensions=extensions,
        )
    )
    return result.scalar_one()


@router.get("")
async def graphql_schema(
    session: Annotated[AsyncSession, Depends(get_graphql_admin_session)]
):
    query_intros = get_introspection_query(descriptions=True)
    result = await session.execute(
        text(
            f"""
            select graphql.resolve(
                (:query)::text
            );
        """
        ).bindparams(query=query_intros)
    )
    intros_result: dict[str, Any] = result.scalar_one()
    client_schema = build_client_schema(intros_result.get("data", None))
    headers = {"Content-Disposition": 'attachment; filename="schema.gql"'}
    return StreamingResponse(
        BytesIO(print_schema(client_schema).encode()), headers=headers
    )
