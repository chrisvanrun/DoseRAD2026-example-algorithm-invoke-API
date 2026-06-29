## Running the container locally

To run the container locally, execute:

    ./do_test_run.sh

This script will:

1. Start the inference server and load your model
2. Wait until the server becomes healthy (i.e. the health endpoint returns HTTP 200 OK)
3. Invoke the algorithm for inference and wait for it to complete (i.e. the invoke endpoint returns HTTP 201 CREATED)

During inference, the container reads input data from:

`./test/input`

and writes output results to:

`./test/output`

## Saving the container

To save the container and prepare it for upload to grand-challenge.org, run:

    ./do_save.sh

## Further documentation

Please note that this is supplementary to the [documentation](https://grand-challenge.org/documentation/algorithms/).

For a step-by-step tutorial, see:
https://grand-challenge.org/documentation/building-and-testing-the-container/

For details about the runtime environment used on the platform, see:
https://grand-challenge.org/documentation/runtime-environment/

If the documentation does not answer your question, feel free to reach out to us at
[support@grand-challenge.org](mailto:support@grand-challenge.org).
