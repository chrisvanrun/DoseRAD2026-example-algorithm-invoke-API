"""
The following is a simple example algorithm.

It is meant to run within a container.

To run the container locally, you can call the following bash script:

  ./do_test_run.sh

This will start the inference and reads from ./test/input and writes to ./test/output

To save the container and prep it for upload to Grand-Challenge.org you can call:

  ./do_save.sh

Any container that shows the same behaviour will do, this is purely an example of how one COULD do it.

Reference the documentation to get details on the runtime environment on the platform:
https://grand-challenge.org/documentation/runtime-environment/

Happy programming!
"""

import glob
import json
from pathlib import Path

import numpy
import SimpleITK
import torch

INPUT_PATH = Path("/input")
OUTPUT_PATH = Path("/output")
RESOURCE_PATH = Path("resources")


def run(model):

    # The key is a tuple of the slugs of the input sockets
    interface_key = get_interface_key()

    # Lookup the handler for this particular set of sockets (i.e. the interface)
    handler = {
        (
            "radiation-dose-calculation-source-ct-image-1",
            "radiation-dose-calculation-source-ct-image-10",
            "radiation-dose-calculation-source-ct-image-2",
            "radiation-dose-calculation-source-ct-image-3",
            "radiation-dose-calculation-source-ct-image-4",
            "radiation-dose-calculation-source-ct-image-5",
            "radiation-dose-calculation-source-ct-image-6",
            "radiation-dose-calculation-source-ct-image-7",
            "radiation-dose-calculation-source-ct-image-8",
            "radiation-dose-calculation-source-ct-image-9",
            "stacked-photon-beam-level-metadata",
        ): interf0_handler,
        (
            "radiation-dose-calculation-source-ct-image-1",
            "radiation-dose-calculation-source-ct-image-10",
            "radiation-dose-calculation-source-ct-image-2",
            "radiation-dose-calculation-source-ct-image-3",
            "radiation-dose-calculation-source-ct-image-4",
            "radiation-dose-calculation-source-ct-image-5",
            "radiation-dose-calculation-source-ct-image-6",
            "radiation-dose-calculation-source-ct-image-7",
            "radiation-dose-calculation-source-ct-image-8",
            "radiation-dose-calculation-source-ct-image-9",
            "stacked-proton-beam-level-metadata",
        ): interf1_handler,
    }[interface_key]

    # Call the handler
    return handler(model)


def interf0_handler(model):
    # Read the input

    print("HELLO from the interf0_handler function")

    input_radiation_dose_calculation_source_ct_image_1 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-1",
    )

    input_radiation_dose_calculation_source_ct_image_2 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-2",
    )

    input_radiation_dose_calculation_source_ct_image_3 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-3",
    )

    input_radiation_dose_calculation_source_ct_image_4 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-4",
    )

    input_radiation_dose_calculation_source_ct_image_5 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-5",
    )

    input_radiation_dose_calculation_source_ct_image_6 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-6",
    )

    input_radiation_dose_calculation_source_ct_image_7 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-7",
    )

    input_radiation_dose_calculation_source_ct_image_8 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-8",
    )

    input_radiation_dose_calculation_source_ct_image_9 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-9",
    )

    input_radiation_dose_calculation_source_ct_image_10 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-10",
    )

    input_stacked_photon_beam_level_metadata = load_json_file(
        location=INPUT_PATH / "stacked-photon-beam-level-metadata.json",
    )

    # Process the inputs: any way you'd like, here we show-case torch

    # Example how to set torch to use the GPU (if available)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model_input = torch.randn(1, 10).to(device)
    model_output = model(model_input)

    # For now, let us make bogus predictions

    output_stacked_radiation_dose_map_1 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_2 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_3 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_4 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_5 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_6 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_7 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_8 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_9 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_10 = numpy.eye(4, 2)

    # Save your output

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-1",
        array=output_stacked_radiation_dose_map_1,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-2",
        array=output_stacked_radiation_dose_map_2,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-3",
        array=output_stacked_radiation_dose_map_3,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-4",
        array=output_stacked_radiation_dose_map_4,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-5",
        array=output_stacked_radiation_dose_map_5,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-6",
        array=output_stacked_radiation_dose_map_6,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-7",
        array=output_stacked_radiation_dose_map_7,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-8",
        array=output_stacked_radiation_dose_map_8,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-9",
        array=output_stacked_radiation_dose_map_9,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-10",
        array=output_stacked_radiation_dose_map_10,
    )

    return 0


def interf1_handler(model):
    # Read the input

    print("HELLO from the interf1_handler function")
           
    input_radiation_dose_calculation_source_ct_image_1 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-1",
    )

    input_radiation_dose_calculation_source_ct_image_2 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-2",
    )

    input_radiation_dose_calculation_source_ct_image_3 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-3",
    )

    input_radiation_dose_calculation_source_ct_image_4 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-4",
    )

    input_radiation_dose_calculation_source_ct_image_5 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-5",
    )

    input_radiation_dose_calculation_source_ct_image_6 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-6",
    )

    input_radiation_dose_calculation_source_ct_image_7 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-7",
    )

    input_radiation_dose_calculation_source_ct_image_8 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-8",
    )

    input_radiation_dose_calculation_source_ct_image_9 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-9",
    )

    input_radiation_dose_calculation_source_ct_image_10 = load_image_file_as_array(
        location=INPUT_PATH / "images/radiation-dose-calculation-source-ct-image-10",
    )

    input_stacked_proton_beam_level_metadata = load_json_file(
        location=INPUT_PATH / "stacked-proton-beam-level-metadata.json",
    )

    # Process the inputs: any way you'd like, here we show-case torch

    # Example how to set torch to use the GPU (if available)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model_input = torch.randn(1, 10).to(device)
    model_output = model(model_input)

    # For now, let us make bogus predictions

    output_stacked_radiation_dose_map_1 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_2 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_3 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_4 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_5 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_6 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_7 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_8 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_9 = numpy.eye(4, 2)

    output_stacked_radiation_dose_map_10 = numpy.eye(4, 2)

    # Save your output

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-1",
        array=output_stacked_radiation_dose_map_1,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-2",
        array=output_stacked_radiation_dose_map_2,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-3",
        array=output_stacked_radiation_dose_map_3,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-4",
        array=output_stacked_radiation_dose_map_4,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-5",
        array=output_stacked_radiation_dose_map_5,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-6",
        array=output_stacked_radiation_dose_map_6,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-7",
        array=output_stacked_radiation_dose_map_7,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-8",
        array=output_stacked_radiation_dose_map_8,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-9",
        array=output_stacked_radiation_dose_map_9,
    )

    write_array_as_image_file(
        location=OUTPUT_PATH / "images/stacked-radiation-dose-map-10",
        array=output_stacked_radiation_dose_map_10,
    )

    return 0


def get_interface_key():
    # The inputs.json is a system generated file that contains information about
    # the inputs that interface with the algorithm
    inputs = load_json_file(
        location=INPUT_PATH / "inputs.json",
    )
    socket_slugs = [sv["socket"]["slug"] for sv in inputs]
    return tuple(sorted(socket_slugs))


def load_json_file(*, location):
    # Reads a json file
    with open(location) as f:
        return json.loads(f.read())


def load_image_file_as_array(*, location):
    # Use SimpleITK to read a file
    input_files = (
        glob.glob(str(location / "*.tif"))
        + glob.glob(str(location / "*.tiff"))
        + glob.glob(str(location / "*.mha"))
    )
    result = SimpleITK.ReadImage(input_files[0])

    # Convert it to a Numpy array
    return SimpleITK.GetArrayFromImage(result)


def write_array_as_image_file(*, location, array):
    location.mkdir(parents=True, exist_ok=True)

    # You may need to change the suffix to .tif to match the expected output
    suffix = ".mha"

    image = SimpleITK.GetImageFromArray(array)
    SimpleITK.WriteImage(
        image,
        location / f"output{suffix}",
        useCompression=True,
    )

if __name__ == "__main__":
    from app import init_model
    raise SystemExit(run(model=init_model()))
