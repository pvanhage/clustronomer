# Clustronomer

Analysis scripts for the quantification and analyses of intracellular clusters derived from fluorescence microscopy images

- Clusters can range from fluorescently labelled microbes to intracellular compartments or protein spots
- ClusterGazer 2D/3D provides an out-of-the-box ImageJ macro that can handle standard processing and quantification
- Quantification and analyses scripts are structured to easily accommodate additional tools or processing steps

Currently, the following scripts are available: 

+  [ClusterGazer2D.ijm](ClusterGazer2D.ijm) : The 2D version of ClusterGazer using standard ImageJ scripting functions
+  [ClusterGazer3D.ijm](ClusterGazer3D.ijm) : The 2D version of ClusterGazer based on 3D imagej suite
+  [SeriesSplitter.ijm](SeriesSplitter.ijm) : A simple image series segmentation macro to split off individual TIFF files

## ClusterGazer 2D/3D

ImageJ macro for simple semi-automated batch quantification of intracellular clusters from fluorescence microscopy images

- Semi-automated thresholding and segmentation of cells, clusters, and protein foci
- Quantifies location, protein intensity, and fraction overlap between objects
- Thresholds can be set per image or fixed for the entire range of images 
- Pre-processing steps kept to a minimum to flexibly extend to user needs
- Z-stacks are merged by maximum Z-projection (ClusterGazer2D) 
- Alternatively, can perform 3D object quantification (ClusterGazer3D)
- Performs per frame quantification for image timeseries
- Output as a single CSV table for downstream analysis

## Requirements

- Up-to-date Fiji / ImageJ
- Operates on individual TIFF files
- Image collections can be split using SeriesSplitter
- ImageJ 3D suite (only required for ClusterGazer3D)

## How to use

Optional: Separate image series into single TIFF files using SeriesSplitter

1. Open the macro in Fiji → Run
2. Select folder consisting of image series
3. Select folder to store individual TIFF files

Batch processing with ClusterGazer

1. Open the macro in Fiji → Run
2. Select your image folder
3. Select folder for the output file
4. Follow prompts to choose channels and settings
5. Channels are automatically pre-processed, and subject to user-defined thresholds
7. Results will be saved as a single CSV

## Additional notes 

- Checking guided mode will give a demonstration of quantified regions of interest (ROIs)
- The script will duplicate channels for each object to perform object-specific pre-processing and measurements
- By setting the cluster channel for protein, intensity measures are performed only on the clusters
- Can easily merge cluster measurements from runs with different protein channels by using the same cluster settings

## Modify object-specific processing steps

- The pre-processing steps can be modified using standard macro functions
- Use Plugins → Macros → Record... to track pre-processing steps
- Use Ctrl/Cmd + F in the clusterGazer script editor to search for "// Insert [object]"
- The [object] can consist of "protein", "cluster", "cell", or "nuclei"
- Paste your desired functions within the channel pre-processing chunk
- Note that all pre-processing operations are made on a "dummy_" image
- If any functions generates a new image, close the old one and rename the new one:

```
selectWindow("dummy_cluster"); 
close(); 
selectWindow("new_image");
rename("dummy_cluster");
```

## Example

The goal of this example is to quantify protein association with bacterial clusters

- Three example TIFF images are found in the Example folder
- Download the images and unzip them
- The example images are confocal Z-stacks consisting of 5 channels

```
Channel 1: Nuclei channel
Channel 2: A vacuolar protein of interest
Channel 3: Transmission light 
Channel 4: Bacterial infection 
Channel 5: Cell background fluorescence
```

1. Select the folder with the images and the output folder
2. Set cluster channel to 4 and protein channel to 3
3. The remainder of the settings can be left default 
4. A window will open to set the threshold for clusters (move top slider)
5. Another window will open to set threshold for protein spots
6. After that, the same thresholds will be applied to all 3 images
7. For each image, bacterial clusters are processed and their protein content quantified
8. After finishing, a table will emerge with the quantifications per bacterial cluster

In addition, the images provide nuclei and cell channels to include for quantification

- Once selected from the main menu, these will open a separate menu with their own settings
- Apart from the channel number, their primary settings can also be left to default
- Separate threshold windows will emerge for these images to be set
- Similar to the clusters, their protein content will also be quantified

Lastly, guided mode can be checked to demonstrate the quantifiable regions of the first image

## Contributions

| Name                                                         | Affiliation                           |
| ------------------------------------------------------------ | ------------------------------------- | 
| [Patrick van Hage](https://github.com/pvanhage/)  | Institute of Biology Leiden (IBL) | 
| [Annemarie Meijer](https://www.universiteitleiden.nl/en/staffmembers/annemarie-meijer) |Institute of Biology Leiden (IBL) |
