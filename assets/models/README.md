# SafeSight ML Models

Place TFLite model files in this directory.

## Required Models

- `yamnet.tflite` - Google YAMNet audio event classifier
  Download from: https://tfhub.dev/google/lite-model/yamnet/classification/tflite/1

- `yamnet_labels.txt` - Class label mapping (521 audio event classes)
  Download from the same TensorFlow Hub page

## Usage

The AudioClassifierService loads these models for on-device
distress sound detection. No audio data leaves the device.
