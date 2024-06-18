# This software is provided to the United States Government (USG) with SBIR Data Rights as defined at Federal Acquisition Regulation 52.227-14, "Rights in Data-SBIR Program" (May 2014) SBIR Rights Notice (Dec 2023-2024) These SBIR data are furnished with SBIR rights under Contract No. H9241522D0001. For a period of 19 years, unless extended in accordance with FAR 27.409(h), after acceptance of all items to be delivered under this contract, the Government will use these data for Government purposes only, and they shall not be disclosed outside the Government (including disclosure for procurement purposes) during such period without permission of the Contractor, except that, subject to the foregoing use and disclosure prohibitions, these data may be disclosed for use by support Contractors. After the protection period, the Government has a paid-up license to use, and to authorize others to use on its behalf, these data for Government purposes, but is relieved of all disclosure prohibitions and assumes no liability for unauthorized use of these data by third parties. This notice shall be affixed to any reproductions of these data, in whole or in part.
# pylint: disable=consider-using-f-string
from random import choices
from time import time
from string import ascii_uppercase, digits
from datetime import datetime
from logging import getLogger, config
from os.path import join, dirname, abspath
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware


# logging.config does not exist when running pytest (it overrides logging)
if config is not None and hasattr(config, "fileConfig"):
    config.fileConfig(
        join(dirname(abspath(__file__)), "../config/logging.conf"),
        disable_existing_loggers=False,
    )

logger = getLogger(__name__)


class RequestLogger(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        idem = "".join(choices(ascii_uppercase + digits, k=6))
        logger.info("rid=%s start request path=%s", idem, request.url.path)
        start_time = time()
        response = await call_next(request)
        process_time = (time() - start_time) * 1000
        formatted_process_time = "{0:.2f}".format(process_time)
        client_ip = (
            "localhost" if request.client is None else getattr(request.client, "host")
        )
        logger.info(
            "rid=%s time=%s ip=%s method=%s path=%s status_code=%s query=%s completed_in=%sms",
            idem,
            datetime.now().isoformat(),
            client_ip,
            request.method,
            request.url.path,
            response.status_code,
            request.url.query,
            formatted_process_time,
        )

        return response
