from fastapi import APIRouter
from service.routers.graphql import router as graphql_router

router = APIRouter(prefix="")
router.include_router(graphql_router)
