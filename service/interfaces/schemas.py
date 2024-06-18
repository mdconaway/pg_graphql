from pydantic import BaseModel
from pydantic.types import JsonValue


class GraphQLRequest(BaseModel):
    operationName: str | None = None
    query: str
    variables: JsonValue | None = None
    extensions: JsonValue | None = None
