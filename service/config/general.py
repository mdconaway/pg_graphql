# This software is provided to the United States Government (USG) with SBIR Data Rights as defined at Federal Acquisition Regulation 52.227-14, "Rights in Data-SBIR Program" (May 2014) SBIR Rights Notice (Dec 2023) These SBIR data are furnished with SBIR rights under Contract No. H9241522D0001. For a period of 19 years, unless extended in accordance with FAR 27.409(h), after acceptance of all items to be delivered under this contract, the Government will use these data for Government purposes only, and they shall not be disclosed outside the Government (including disclosure for procurement purposes) during such period without permission of the Contractor, except that, subject to the foregoing use and disclosure prohibitions, these data may be disclosed for use by support Contractors. After the protection period, the Government has a paid-up license to use, and to authorize others to use on its behalf, these data for Government purposes, but is relieved of all disclosure prohibitions and assumes no liability for unauthorized use of these data by third parties. This notice shall be affixed to any reproductions of these data, in whole or in part.
from __future__ import annotations
from typing import Any
from pydantic import model_validator
from service.config._base import Base


class General(Base):
    PROJECT_NAME: str = "service"
    API_VERSION: str = "0.1.0"
    MOUNT_PATH: str = "/"

    @model_validator(mode="after")
    def valid_mount_path(self) -> Any:
        self.MOUNT_PATH = (
            ""
            if isinstance(self.MOUNT_PATH, str) and self.MOUNT_PATH == "/"
            else self.MOUNT_PATH
        )
        return self


general = General()
