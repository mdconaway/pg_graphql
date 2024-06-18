# This software is provided to the United States Government (USG) with SBIR Data Rights as defined at Federal Acquisition Regulation 52.227-14, "Rights in Data-SBIR Program" (May 2014) SBIR Rights Notice (Dec 2023-2024) These SBIR data are furnished with SBIR rights under Contract No. H9241522D0001. For a period of 19 years, unless extended in accordance with FAR 27.409(h), after acceptance of all items to be delivered under this contract, the Government will use these data for Government purposes only, and they shall not be disclosed outside the Government (including disclosure for procurement purposes) during such period without permission of the Contractor, except that, subject to the foregoing use and disclosure prohibitions, these data may be disclosed for use by support Contractors. After the protection period, the Government has a paid-up license to use, and to authorize others to use on its behalf, these data for Government purposes, but is relieved of all disclosure prohibitions and assumes no liability for unauthorized use of these data by third parties. This notice shall be affixed to any reproductions of these data, in whole or in part.
from __future__ import annotations
from pydantic import PostgresDsn, model_validator
from service.config._base import Base


class Adapters(Base):
    # Postgresql config
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str
    POSTGRES_HOST: str
    POSTGRES_PORT: int | str
    DATABASE_ECHO: bool = True
    DATABASE_NAME: str
    DATABASE_POOL_SIZE: int
    DATABASE_MAX_OVERFLOW: int
    DATABASE_URI: str | None = None
    DATABASE_ROLE: str = "app_user"

    @model_validator(mode="after")
    def assemble_db_connection(self):
        if self.DATABASE_URI is not None:
            return self
        self.DATABASE_URI = str(
            PostgresDsn.build(  # type: ignore # pylint: disable=no-member,useless-suppression
                scheme="postgresql+asyncpg",
                username=self.POSTGRES_USER,
                password=self.POSTGRES_PASSWORD,
                host=str(self.POSTGRES_HOST),
                port=int(self.POSTGRES_PORT),
                path=f"{self.DATABASE_NAME or ''}",
            )
        )
        return self


adapters = Adapters()  # type: ignore
