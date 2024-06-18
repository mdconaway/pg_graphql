from typing import Any
from fastapi import Request
from sqlalchemy import text
from sqlalchemy.ext.asyncio.session import AsyncSession


async def dump_session_attributes(request: Request, session: AsyncSession):
    user_id = str(getattr(request.state, "user_id", ""))
    # All session-like things must be set here on this one active session as LOCAL SETTINGS
    # Each value should be dot-notated, and have the third value set as "true", which means "only for this transaction"
    # Additionally, set_config only accepts string values, so complex values must be stringified!
    await session.execute(
        text(
            f"select set_config('auth.session.id', (:user_id)::text, true);"
        ).bindparams(user_id=user_id)
    )
