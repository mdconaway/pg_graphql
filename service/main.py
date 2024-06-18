from logging import getLogger
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi_offline import FastAPIOffline
from service.middleware.requestlogger import RequestLogger
from service.routers.application import router as application_router
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

app.include_router(application_router)

app.mount("/", StaticFiles(directory="service/static", html=True), name="static_root")
app.mount("", StaticFiles(directory="service/static", html=True), name="static_blank")
