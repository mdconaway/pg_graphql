from typing import Any, Annotated
from fastapi import Request, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio.session import AsyncSession
from service.adapters.postgres import get_graphql_admin_session


async def become_first_account(
    request: Request,
    session: Annotated[AsyncSession, Depends(get_graphql_admin_session)],
):
    query = """
        {
            accountCollection(first:1){
                edges{
                    node{
                        id
                    }
                }
            }
        }
    """
    result = await session.execute(
        text(
            f"""
            select graphql.resolve(
                (:query)::text
            );
        """
        ).bindparams(query=query)
    )

    result_json: dict[str, Any] = result.scalar_one()
    setattr(
        request.state,
        "user_id",
        result_json["data"]["accountCollection"]["edges"][0]["node"]["id"],
    )
