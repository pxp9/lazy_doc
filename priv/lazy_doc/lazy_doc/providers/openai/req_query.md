Returns a request configuration for querying an AI model with specified parameters.

## Parameters

- prompt - the input text that will be sent to the model for processing.
- model - the identifier for the AI model to be used for the query.
- token - the authorization token required to access the model service.
- params - a keyword list of optional parameters for temperature, top_p, and max_completion_tokens.

## Description
Sets up the request with default values and prepares the body for the API call.