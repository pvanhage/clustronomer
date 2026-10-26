// MIT License
// Copyright (c) 2025 Patrick van Hage
//
// This script is licensed under the MIT License.
// See the LICENSE file in the repository root for details.

// Input directories
inputfolder = getDirectory("Select a directory containing the raw files");
outputfolder = getDirectory("Select a directory to store the results");

// Input settings
Dialog.create("ClusterGazer 2D v1.0.2-alpha");
  Dialog.addMessage("Input settings for ClusterGazer 2D");
  
  Dialog.addMessage("---------- Set channel number to match content ---------");
  Dialog.addNumber("Cluster channel", 1);
  Dialog.addNumber("Signal channel", 2);
  
  Dialog.addMessage("--------- Choose cluster ROI threshold method --------");
  Dialog.addChoice("Threshold method", newArray("Manual (fixed value)", "Manual (set per image)", "Default" , "Huang", "Intermodes", "IsoData", "IJ_IsoData", "Li", "MaxEntropy", "Mean", "MinError", "Minimum", "Moments", "Otsu", "Percentile", "RenyiEntropy", "Shanbhag", "Triangle", "Yen"));
  Dialog.addNumber("Minimum cluster size", 10);
  Dialog.addChoice("Units", newArray("pixel", "micron^2"));
  Dialog.addNumber("Enlarge ROI (µm)", 0);
  Dialog.addNumber("Create band (µm)", 0);
  Dialog.addCheckbox("Watershed segment clusters", true);
  Dialog.addCheckbox("Remove extracellular clusters (whole-cell marker)", false);
  
  Dialog.addMessage("------------ Signal detection within cluster ROI ----------");
  Dialog.addChoice("Signal threshold", newArray("Fixed value", "Set per image"));
  Dialog.addNumber("Minimum signal foci size", 0);
  Dialog.addChoice("Units", newArray("pixel", "micron^2"));
  Dialog.addCheckbox("Remove extracellular signal (whole-cell marker)", false);
  
  Dialog.addMessage("------------------------ Quantify cell content -------------------");
  Dialog.addCheckbox("Whole-cell marker", false);
  Dialog.addCheckbox("Nuclei (Voronoi)", false);
  Dialog.addCheckbox("Signal foci", false);
  
  Dialog.addMessage("---------------------- Miscellaneous settings ----------------");
  Dialog.addString("Output file (.csv)", "Results");
  Dialog.addCheckbox("Guided mode", false);
  
  Dialog.show();
  
  c_cluster = Dialog.getNumber();
  c_signal = Dialog.getNumber();
  
  t_cluster = Dialog.getChoice();
  size_cluster = Dialog.getNumber();
  unit_cluster = Dialog.getChoice();
  roi_enlarge = Dialog.getNumber();
  roi_band = Dialog.getNumber();
  split_cluster = Dialog.getCheckbox();
  remove_cluster = Dialog.getCheckbox();
  
  t_signal = Dialog.getChoice();
  size_signal = Dialog.getNumber();
  unit_signal = Dialog.getChoice();
  remove_signal = Dialog.getCheckbox();
  
  quant_cell = Dialog.getCheckbox();
  quant_nucl = Dialog.getCheckbox();
  quant_signal = Dialog.getCheckbox();
  
  name_result_file = Dialog.getString();
  guide_check = Dialog.getCheckbox();

// Whole-cell enumeration / extracellular cluster removal dialogue
if(quant_cell | remove_cluster | remove_signal) {
	
	Dialog.create("Settings whole-cell marker threshold");

	Dialog.addMessage("Settings marker threshold");
 	Dialog.addNumber("Marker channel", 1);
  	Dialog.addChoice("threshold method", newArray("Manual (fixed value)", "Manual (set per image)", "Default", "Huang", "Intermodes", "IsoData", "IJ_IsoData", "Li", "MaxEntropy", "Mean", "MinError", "Minimum", "Moments", "Otsu", "Percentile", "RenyiEntropy", "Shanbhag", "Triangle", "Yen"));
  	Dialog.addNumber("Minimum cell size", 25);
  	Dialog.addChoice("Units", newArray("micron^2", "pixel"));
  	Dialog.addMessage("Filter to smooth image for thresholding");
  	Dialog.addNumber("Gaussian blur (micron)", 0.5);
  	Dialog.addCheckbox("Watershed segmentation", false);
  
  	Dialog.show();
  
  	c_marker = Dialog.getNumber();
  	t_marker = Dialog.getChoice();
  	size_marker = Dialog.getNumber();
  	unit_marker = Dialog.getChoice();
  	gaus_marker = Dialog.getNumber();
  	split_marker = Dialog.getCheckbox();
  
}

// Nuclei segmentation dialogue
if(quant_nucl) {
	
	Dialog.create("Enumerate nuclei");
	
	Dialog.addMessage("Settings nuclei threshold");
	Dialog.addNumber("Nuclei channel", 1);
	Dialog.addChoice("Threshold method", newArray("Manual (fixed value)", "Manual (set per image)", "Default", "Huang", "Intermodes", "IsoData", "IJ_IsoData", "Li", "MaxEntropy", "Mean", "MinError", "Minimum", "Moments", "Otsu", "Percentile", "RenyiEntropy", "Shanbhag", "Triangle", "Yen"));
  	Dialog.addNumber("Minimum nuclei size", 10);
  	Dialog.addChoice("Units", newArray("micron^2", "pixel"));
  	Dialog.addMessage("Filter to smooth image for thresholding");
  	Dialog.addNumber("Gaussian blur (micron)", 0.5);
  	Dialog.addCheckbox("Watershed segmentation", false);
	
	Dialog.show();
	
	c_nucl = Dialog.getNumber();
	t_nucl = Dialog.getChoice();
  	size_nucl = Dialog.getNumber();
  	unit_nucl = Dialog.getChoice();
  	gaus_nucl = Dialog.getNumber();
  	split_nucl = Dialog.getCheckbox();
	
}

// Identify TIFF files in folder
files_dir = getFileList(inputfolder);
file_names = newArray();
for (i = 0; i < lengthOf(files_dir); i++) {
    if (endsWith(files_dir[i], ".tif")) { 
        file_names = Array.concat(file_names, files_dir[i]);
    } 
}

// Create table and set counters
Table.create("Results");
obj_ind = 0;
obj_ind_frac = 0;

// Loop through image files 
for (l = 0; l < lengthOf(file_names); l++) {
	
	// Open file, get metadata, and set global settings
	open(inputfolder + file_names[l]);
	getDimensions(width, height, channels, slices, frames);	
	getVoxelSize(vox_width, vox_height, vox_depth, vox_unit);
	n_bit = bitDepth(); 
	max_greyval =  pow(2, n_bit) - 1;
	run("Set Measurements...", "area mean standard min centroid integrated median shape display redirect=None decimal=9");
	run("Options...", "iterations=1 count=1");

	// Convert units whole-cell marker 
	if(quant_cell | remove_cluster | remove_signal) {
		if (unit_marker == "micron^2") {
			size_marker_px = size_marker / (vox_width * vox_height * vox_depth);
			size_marker_px = round(size_marker_px);
			size_marker_mu = size_marker;
		} else {
			size_marker_px = size_marker;
			size_marker_mu = size_marker * (vox_width * vox_height * vox_depth);
		}	
	}

	// Convert units nuclei ROI
	if(quant_nucl) {
		if (unit_nucl == "micron^2") {
			size_nucl_px = size_nucl / (vox_width * vox_height * vox_depth);
			size_nucl_px = round(size_nucl_px);
			size_nucl_mu = size_nucl;
		} else {
			size_nucl_px = size_nucl;
			size_nucl_mu = size_nucl * (vox_width * vox_height * vox_depth);
		}	
	}
	
	// Convert units cluster ROI
	if (unit_cluster == "micron^2") {
		size_cluster_px = size_cluster / (vox_width * vox_height * vox_depth);
		size_cluster_px = round(size_cluster_px);
		size_cluster_mu = size_cluster;
	} else {
		size_cluster_px = size_cluster;
		size_cluster_mu = size_cluster * (vox_width * vox_height * vox_depth);
	}
	
	// Convert units signal ROI
	if (unit_signal == "micron^2") {
		size_signal_px = size_signal / (vox_width * vox_height * vox_depth);
		size_signal_px = round(size_signal_px);
		size_signal_mu = size_signal;
	} else {
		size_signal_px = size_signal;
		size_signal_mu = size_signal * (vox_width * vox_height * vox_depth);
	}
	
	// Merge slices using maximum Z projection
	if(slices > 1) {
		run("Z Project...", "projection=[Max Intensity] all");
		image_title = "MAX_" + file_names[l];
		selectWindow(file_names[l]);
		close();
	} else {
		image_title = file_names[l];
	}
	run("Split Channels");
	
	// Process cell marker channel
	if(quant_cell | remove_cluster | remove_signal) {
		
		selectWindow("C" + c_marker + "-" + image_title);
		run("Duplicate...", "title=dummy_marker duplicate");
		selectWindow("dummy_marker");
		
		// Insert cell marker channel pre-threshold processing steps
		run("Gaussian Blur...", "sigma="+ gaus_marker +" scaled stack");
		// End of cell marker channel pre-threshold processing steps
		
		if(t_marker == "Manual (set per image)") {
			
			setAutoThreshold("Huang dark");
			run("Threshold...");
			getThreshold(MinThresh_marker, MaxThresh_marker);
			waitForUser("Set threshold for whole-cell marker per image. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
			getThreshold(MinThresh_marker, MaxThresh_marker);
			selectWindow("Threshold");
			run("Close");
		
		} else if (t_marker == "Manual (fixed value)") {
			
			if(l == 0) {
				
				setAutoThreshold("Huang dark");
				run("Threshold...");
				getThreshold(MinThresh_marker, MaxThresh_marker);
				waitForUser("Set a fixed threshold for whole-cell marker. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
				getThreshold(MinThresh_marker, MaxThresh_marker);
				selectWindow("Threshold");
				run("Close");	
			}
		
		} else {
			
			setAutoThreshold(t_marker + " dark");
			getThreshold(MinThresh_marker, MaxThresh_marker);
		}
		
		setThreshold(MinThresh_marker, MaxThresh_marker);
		run("Convert to Mask", "stack");
		if(split_marker) run("Watershed", "stack");
	
	}

	// Process nuclei channel
	if(quant_nucl) {
		
		selectWindow("C" + c_nucl + "-" + image_title);
		run("Duplicate...", "title=dummy_nucl duplicate");
		selectWindow("dummy_nucl");
		
		// Insert nuclei channel pre-threshold processing steps
		run("Gaussian Blur...", "sigma="+ gaus_nucl +" scaled stack");
		// End of nuclei channel pre-threshold processing steps
		
		if(t_nucl == "Manual (set per image)") {
			
			setAutoThreshold("Default dark");
			run("Threshold...");
			getThreshold(MinThresh_nucl, MaxThresh_nucl);
			waitForUser("Set threshold for nuclei per image. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
			getThreshold(MinThresh_nucl, MaxThresh_nucl);
			selectWindow("Threshold");
			run("Close");
		
		} else if (t_nucl == "Manual (fixed value)") {
			
			if(l == 0) {
				
				setAutoThreshold("Default dark");
				run("Threshold...");
				getThreshold(MinThresh_nucl, MaxThresh_nucl);
				waitForUser("Set a fixed threshold for nuclei. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
				getThreshold(MinThresh_nucl, MaxThresh_nucl);
				selectWindow("Threshold");
				run("Close");	
			}
		
		} else {
			
			setAutoThreshold(t_nucl + " dark");
			getThreshold(MinThresh_nucl, MaxThresh_nucl);
		}
		
		setThreshold(MinThresh_nucl, MaxThresh_nucl);
		run("Convert to Mask", "stack");
		if(split_nucl) run("Watershed", "stack");
	}

	// Process cluster channel
	selectWindow("C" + c_cluster + "-" + image_title);
	run("Duplicate...", "title=dummy_cluster duplicate");
	selectWindow("dummy_cluster");
	
	// Insert cluster channel pre-threshold processing steps
	run("Smooth", "stack");
	// End of cluster channel pre-threshold processing steps
	
	if(t_cluster == "Manual (set per image)") {
		
		setAutoThreshold("Default dark");
		run("Threshold...");
		getThreshold(MinThresh_cluster, MaxThresh_cluster);
		waitForUser("Set threshold for cluster ROIs per image. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
		getThreshold(MinThresh_cluster, MaxThresh_cluster);
		selectWindow("Threshold");
		run("Close");
	
	} else if (t_cluster == "Manual (fixed value)") {
		
		if(l == 0) {
			
			setAutoThreshold("Default dark");
			run("Threshold...");
			getThreshold(MinThresh_cluster, MaxThresh_cluster);
			waitForUser("Set a fixed threshold for cluster ROIs. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
			getThreshold(MinThresh_cluster, MaxThresh_cluster);
			selectWindow("Threshold");
			run("Close");
		}
	
	} else {
		
		setAutoThreshold(t_cluster + " dark");
		getThreshold(MinThresh_cluster, MaxThresh_cluster);
	}
	
	setThreshold(MinThresh_cluster, MaxThresh_cluster);
	run("Convert to Mask", "stack");
	if(split_cluster) run("Watershed", "stack");

	// Process signal channel
	selectWindow("C" + c_signal + "-" + image_title);
	run("Duplicate...", "title=dummy_signal duplicate");
	selectWindow("dummy_signal");
	
	// Insert signal channel pre-threshold processing steps
	run("Smooth", "stack");
	// End of signal channel pre-threshold processing steps
	
	if(t_signal == "Set per image") {
		
		setAutoThreshold("Yen dark");
		run("Threshold...");
		getThreshold(MinThresh_signal, MaxThresh_signal);
		waitForUser("Set threshold signal per image. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
		getThreshold(MinThresh_signal, MaxThresh_signal);
		selectWindow("Threshold");
		run("Close");
	
	} else if (l == 0) {
			
			setAutoThreshold("Yen dark");
			run("Threshold...");
			getThreshold(MinThresh_signal, MaxThresh_signal);
			waitForUser("Set a fixed threshold for signal. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
			getThreshold(MinThresh_signal, MaxThresh_signal);
			selectWindow("Threshold");
			run("Close");
	
	}
	setThreshold(MinThresh_signal, MaxThresh_signal);
	run("Convert to Mask", "stack");


	// Subtract cell marker from cluster or signal channel
	if(remove_cluster | remove_signal) {
		
		selectWindow("dummy_marker");
		
		if (unit_marker == "micron^2") {
			run("Analyze Particles...", "size=" + size_marker + "-Infinity stack show=Masks");
		} else {
			run("Analyze Particles...", "size=" + size_marker + "-Infinity pixel stack show=Masks");
		}
		
		selectWindow("Mask of dummy_marker");
		run("Invert", "stack");
		if(remove_cluster) imageCalculator("Subtract stack", "dummy_cluster","Mask of dummy_marker");
		if(remove_signal) imageCalculator("Subtract stack", "dummy_signal","Mask of dummy_marker");
		selectWindow("Mask of dummy_marker");
		close;
	
	}

	// Loop quantifications per time frame 
	for(t = 1; t < (frames + 1); t++) {
		
		// Analyze clusters per slice and add to ROI manager
		selectWindow("dummy_cluster");
		Stack.setFrame(t);
		
		if (unit_cluster == "micron^2") {
			run("Analyze Particles...", "size=" + size_cluster_mu + "-Infinity add slice show=Masks");
		} else {
			run("Analyze Particles...", "size=" + size_cluster_px + "-Infinity pixel add slice show=Masks");
		}
		
		if(guide_check & (l == 0) & (t == 1)) {
			
			selectWindow("C" + c_cluster + "-" + image_title);
			Stack.setFrame(t);
			roiManager("Show All without labels");
			waitForUser("Example of the thresholded cluster ROIs. \nPress OK to continue.");
		
		}

		// Analyze signal foci per slice and create mask
		selectWindow("dummy_signal");
		Stack.setFrame(t);
		
		if(unit_signal == "micron^2") {
			run("Analyze Particles...", "size=" + size_signal_mu + "-Infinity slice show=Masks");
		} else {
			run("Analyze Particles...", "size=" + size_signal_px + "-Infinity pixel slice show=Masks");
		}
		
		// Measure total signal intensity within each cluster ROI
		selectWindow("Mask of dummy_cluster");
		n_cluster = roiManager("count");
		
		if(n_cluster > 0) {
			
			selectWindow("C" + c_signal + "-" + image_title);
			Stack.setFrame(t);
			
			for(n = 0; n < n_cluster; n++) {
				
				roiManager("Select", n);
				run("Enlarge...", "enlarge=" + roi_enlarge);
		    	roiManager("Update");
		    	
		    	selectWindow("C" + c_signal + "-" + image_title);
		    	Stack.setFrame(t);
		    	
		    	roiManager("Select", n);
		    	run("Measure");
		    	
		    	Table.set("Label", obj_ind, file_names[l]);
				Table.set("Frame", obj_ind, t);
				Table.set("ID", obj_ind, (n + 1));
				Table.set("Type", obj_ind, "Cluster");
		    	
		    	obj_ind = obj_ind + 1;
				
			}
			
			if(guide_check & (l == 0) & (t == 1)) {
				
				selectWindow("C" + c_signal + "-" + image_title);
				roiManager("Show All without labels");
				waitForUser("Example of signal intensity with cluster ROIs. \nPress OK to continue.");
			
			}
			
			// Signal fraction of cluster ROI covered 
			selectWindow("Mask of dummy_signal");
			n_bit_mask = bitDepth(); 
			max_greyval_mask =  pow(2, n_bit_mask) - 1;
			
			for(n = 0; n < n_cluster; n++) {
				
				selectWindow("Mask of dummy_signal");
				roiManager("Select", n);
				List.setMeasurements();
				signal_frac_bit = List.getValue("Mean");
		    	signal_frac = (signal_frac_bit / max_greyval_mask);
		    	
		    	Table.set("FractionSignal", obj_ind_frac, signal_frac);
		    	Table.set("FractionCluster", obj_ind_frac, 1);
		    	Table.set("MinThreshObject", obj_ind_frac, MinThresh_cluster);
				Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_cluster);
				Table.set("MinThreshSignal", obj_ind_frac, MinThresh_signal);
				Table.set("MaxThreshSignal", obj_ind_frac, MaxThresh_signal);
		    	
		    	obj_ind_frac = obj_ind_frac + 1;
			}
			
			if((guide_check == 1) & (l == 0) & (t == 1)) {
				
				selectWindow("Mask of dummy_signal");
				roiManager("Show All without labels");
				waitForUser("Example of thresholded signal overlap with cluster ROIs. \nPress OK to continue.");
			}
			
			// Create cluster band and measure
			if(roi_band > 0) {
					
				selectWindow("C" + c_signal + "-" + image_title);
				Stack.setFrame(t)
					
				for(n = 0; n < n_cluster; n++) {
					
					roiManager("Select", n);
					run("Make Band...", "band=" + roi_band);
					roiManager("Update");
						
					selectWindow("C" + c_signal + "-" + image_title);
					Stack.setFrame(t);
			    	
			    	roiManager("Select", n);
			    	run("Measure");
			    		
			    	Table.set("Label", obj_ind, file_names[l]);
			    	Table.set("Frame", obj_ind, t);
			    	Table.set("ID", obj_ind, (n + 1));
			    	Table.set("Type", obj_ind, "Band");
			    		
			    	obj_ind = obj_ind + 1;
				}
				
				selectWindow("Mask of dummy_signal");
				n_bit_mask = bitDepth(); 
				max_greyval_mask =  pow(2, n_bit_mask) - 1;
			
				for(n = 0; n < n_cluster; n++) {
						
					selectWindow("Mask of dummy_signal");
					roiManager("Select", n);
					List.setMeasurements();
					signal_frac_bit = List.getValue("Mean");
				    signal_frac = (signal_frac_bit / max_greyval_mask);
				    	
				    Table.set("FractionSignal", obj_ind_frac, signal_frac);
				    Table.set("FractionCluster", obj_ind_frac, 1);
				    Table.set("MinThreshObject", obj_ind_frac, MinThresh_cluster);
					Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_cluster);
					Table.set("MinThreshSignal", obj_ind_frac, MinThresh_signal);
					Table.set("MaxThreshSignal", obj_ind_frac, MaxThresh_signal);
				    	
				    obj_ind_frac = obj_ind_frac + 1;
				}
				
				
			}
			
			roiManager("Deselect");
			roiManager("Delete");
		}
		
		// Quantify cell content per frame
		if(quant_cell) {
			
			selectWindow("dummy_marker");
			Stack.setFrame(t);
			
			if (unit_marker == "micron^2") {
				run("Analyze Particles...", "size=" + size_marker_mu + "-Infinity slice add");
			} else {
				run("Analyze Particles...", "size=" + size_marker_px + "-Infinity pixel slice add");
			}
			n_cell = roiManager("count");	
			
			if(guide_check & (l == 0) & (t == 1)) {
				
				selectWindow("C" + c_marker + "-" + image_title);
				Stack.setFrame(t);
				roiManager("Show All without labels");
				waitForUser("Example of segmented cell ROIs. \nPress OK to continue.");
			}
			
			if(n_cell > 0) {
				
				// Signal intensity in cell
				selectWindow("C" + c_signal + "-" + image_title);
				Stack.setFrame(t);
				
				for(n = 0; n < n_cell; n++) {
					
					selectWindow("C" + c_signal + "-" + image_title);
					Stack.setFrame(t);
					roiManager("Select", n);
			    	run("Measure");
			    	
			    	Table.set("Label", obj_ind, file_names[l]);
					Table.set("Frame", obj_ind, t);
					Table.set("ID", obj_ind, (n + 1));
					Table.set("Type", obj_ind, "Cell");
					
					obj_ind = obj_ind + 1;
				}
				
				// Fraction of cell covered by signal
				selectWindow("Mask of dummy_signal");
				n_bit_mask = bitDepth(); 
				max_greyval_mask =  pow(2, n_bit_mask) - 1;
				
				for(n = 0; n < n_cell; n++) {
					
					selectWindow("Mask of dummy_signal");
					roiManager("Select", n);
					List.setMeasurements();
					signal_frac_bit = List.getValue("Mean");
			    	signal_frac = (signal_frac_bit / max_greyval_mask);
			    	
			    	Table.set("FractionSignal", obj_ind_frac, signal_frac);
			    	Table.set("MinThreshObject", obj_ind_frac, MinThresh_marker);
					Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_marker);
					Table.set("MinThreshSignal", obj_ind_frac, MinThresh_signal);
					Table.set("MaxThreshSignal", obj_ind_frac, MaxThresh_signal);
			    	
			    	obj_ind_frac = obj_ind_frac + 1;
				}
				
				// Fraction of cell covered by cluster
				obj_ind_frac = obj_ind_frac - n_cell;
				selectWindow("Mask of dummy_cluster");
				n_bit_mask = bitDepth(); 
				max_greyval_mask =  pow(2, n_bit_mask) - 1;
				
				for(n = 0; n < n_cell; n++) {
					
					selectWindow("Mask of dummy_cluster");
					roiManager("Select", n);
					List.setMeasurements();
					cluster_frac_bit = List.getValue("Mean");
			    	cluster_frac = (cluster_frac_bit / max_greyval_mask);
			    	
			    	Table.set("FractionCluster", obj_ind_frac, cluster_frac);
			    	
			    	obj_ind_frac = obj_ind_frac + 1;
				}	
				
				roiManager("Deselect");
				roiManager("Delete");
			}
		}
		 
		// Quantify nuclei content per frame
		if(quant_nucl) {
			
			selectWindow("dummy_nucl");
			Stack.setFrame(t);
			
			if (unit_nucl == "micron^2") {
				run("Analyze Particles...", "size=" + size_nucl_mu + "-Infinity add slice show=Masks");
			} else {
				run("Analyze Particles...", "size=" + size_nucl_px + "-Infinity pixel add slice show=Masks");
			}		
			n_nucl = roiManager("count");
			
			if(n_nucl > 0) {
				
				selectWindow("C" + c_signal + "-" + image_title);
				Stack.setFrame(t);
				
				for(n = 0; n < n_nucl; n++) {
					
			    	selectWindow("C" + c_signal + "-" + image_title);
					Stack.setFrame(t);
			    	
			    	roiManager("Select", n);
			    	run("Measure");
			    	
			    	Table.set("Label", obj_ind, file_names[l]);
					Table.set("Frame", obj_ind, t);
					Table.set("ID", obj_ind, (n + 1));
					Table.set("Type", obj_ind, "Nucleus");
			    	
			    	obj_ind = obj_ind + 1;
				}
				
				// Fraction of nucleus covered by signal
				selectWindow("Mask of dummy_signal");
				n_bit_mask = bitDepth(); 
				max_greyval_mask =  pow(2, n_bit_mask) - 1;
				
				for(n = 0; n < n_nucl; n++) {
					
					selectWindow("Mask of dummy_signal");
					roiManager("Select", n);
					List.setMeasurements();
					signal_frac_bit = List.getValue("Mean");
			    	signal_frac = (signal_frac_bit / max_greyval_mask);
			    	
			    	Table.set("FractionSignal", obj_ind_frac, signal_frac);
			    	Table.set("MinThreshObject", obj_ind_frac, MinThresh_nucl);
					Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_nucl);
					Table.set("MinThreshSignal", obj_ind_frac, MinThresh_signal);
					Table.set("MaxThreshSignal", obj_ind_frac, MaxThresh_signal);
			    	
			    	obj_ind_frac = obj_ind_frac + 1;
				}
				
				// Fraction of nuclei covered by cluster
				obj_ind_frac = obj_ind_frac - n_nucl;
				selectWindow("Mask of dummy_cluster");
				n_bit_mask = bitDepth(); 
				max_greyval_mask =  pow(2, n_bit_mask) - 1;	
					
				for(n = 0; n < n_nucl; n++) {
					
					selectWindow("Mask of dummy_cluster");
					roiManager("Select", n);
					List.setMeasurements();
					cluster_frac_bit = List.getValue("Mean");
			    	cluster_frac = (cluster_frac_bit / max_greyval_mask);
			    	
			    	Table.set("FractionCluster", obj_ind_frac, cluster_frac);
			    	
			    	obj_ind_frac = obj_ind_frac + 1;
				}	
				
				roiManager("Deselect");
				roiManager("Delete");	
				
				// Create and quantify Voronoi
				selectWindow("Mask of dummy_nucl");
				run("Voronoi");
				setThreshold(0, 0);
				run("Convert to Mask");
				
				selectWindow("Mask of dummy_nucl");
				run("Analyze Particles...", "add");
				n_voronoi = roiManager("count");
						
				if(guide_check & (l == 0) & (t == 1)) {
					
					selectWindow("C" + c_nucl + "-" + image_title);
					Stack.setFrame(t);
					roiManager("Show All without labels");
					waitForUser("Example of Voronoi segmentation to quantify cell content. \nPress OK to continue.");
				}
				
				if(n_voronoi > 0) {
					
					selectWindow("C" + c_signal + "-" + image_title);
					Stack.setFrame(t);
					
					for(n = 0; n < n_voronoi; n++) {
						
				    	selectWindow("C" + c_signal + "-" + image_title);
						Stack.setFrame(t);
				    	
				    	roiManager("Select", n);
				    	run("Measure");
				    	
				    	Table.set("Label", obj_ind, file_names[l]);
						Table.set("Frame", obj_ind, t);
						Table.set("ID", obj_ind, (n + 1));
						Table.set("Type", obj_ind, "Voronoi");
				    	
				    	obj_ind = obj_ind + 1;
					}
					
					// Fraction of Voronoi area covered by signal
					selectWindow("Mask of dummy_signal");
					n_bit_mask = bitDepth(); 
					max_greyval_mask =  pow(2, n_bit_mask) - 1;
					
					for(n = 0; n < n_voronoi; n++) {
						
						selectWindow("Mask of dummy_signal");
						roiManager("Select", n);
						List.setMeasurements();
						signal_frac_bit = List.getValue("Mean");
				    	signal_frac = (signal_frac_bit / max_greyval_mask);
				    	
				    	Table.set("FractionSignal", obj_ind_frac, signal_frac);
				    	Table.set("MinThreshObject", obj_ind_frac, MinThresh_nucl);
						Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_nucl);
						Table.set("MinThreshSignal", obj_ind_frac, MinThresh_signal);
						Table.set("MaxThreshSignal", obj_ind_frac, MaxThresh_signal);
				    	
				    	obj_ind_frac = obj_ind_frac + 1;
					}
					
					// Fraction of Voronoi area covered by cluster
					obj_ind_frac = obj_ind_frac - n_voronoi;
					selectWindow("Mask of dummy_cluster");
					n_bit_mask = bitDepth(); 
					max_greyval_mask =  pow(2, n_bit_mask) - 1;
					
					for(n = 0; n < n_voronoi; n++) {
						
						selectWindow("Mask of dummy_cluster");
						roiManager("Select", n);
						List.setMeasurements();
						cluster_frac_bit = List.getValue("Mean");
				    	cluster_frac = (cluster_frac_bit / max_greyval_mask);
				    	
				    	Table.set("FractionCluster", obj_ind_frac, cluster_frac);
				    	
				    	obj_ind_frac = obj_ind_frac + 1;
					}	
					
					roiManager("Deselect");
					roiManager("Delete");			
				}
			}
							
			selectWindow("Mask of dummy_nucl");
			close;
		}
		
		if(quant_signal) {
			
			selectWindow("Mask of dummy_signal");
			run("Select None");
			run("Analyze Particles...", "add");
			n_signal = roiManager("count");
					
			if(guide_check & (l == 0) & (t == 1)) {
				
				selectWindow("C" + c_signal + "-" + image_title);
				Stack.setFrame(t);
				roiManager("Show All without labels");
				waitForUser("Example of signal foci. \nPress OK to continue.");
			}
			
			if(n_signal > 0) {
				
				selectWindow("C" + c_signal + "-" + image_title);
				Stack.setFrame(t);
				
				for(n = 0; n < n_signal; n++) {
					
			    	selectWindow("C" + c_signal + "-" + image_title);
					Stack.setFrame(t);
			    	
			    	roiManager("Select", n);
			    	run("Measure");
			    	
			    	Table.set("Label", obj_ind, file_names[l]);
					Table.set("Frame", obj_ind, t);
					Table.set("ID", obj_ind, (n + 1));
					Table.set("Type", obj_ind, "Signal");
			    	
			    	obj_ind = obj_ind + 1;
				}
				
				// Fraction of signal foci covered by cluster
				selectWindow("Mask of dummy_cluster");
				n_bit_mask = bitDepth(); 
				max_greyval_mask =  pow(2, n_bit_mask) - 1;
				
				for(n = 0; n < n_signal; n++) {
					
					selectWindow("Mask of dummy_cluster");
					roiManager("Select", n);
					List.setMeasurements();
					cluster_frac_bit = List.getValue("Mean");
			    	cluster_frac = (cluster_frac_bit / max_greyval_mask);
			    	
			    	Table.set("FractionSignal", obj_ind_frac, 1);
			    	Table.set("FractionCluster", obj_ind_frac, cluster_frac);
			    	Table.set("MinThreshObject", obj_ind_frac, MinThresh_signal);
					Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_signal);
					Table.set("MinThreshSignal", obj_ind_frac, MinThresh_signal);
					Table.set("MaxThreshSignal", obj_ind_frac, MaxThresh_signal);
			    	
			    	obj_ind_frac = obj_ind_frac + 1;
				}	
				
				roiManager("Deselect");
				roiManager("Delete");			
			}
			
		}
		 
		// Reset mask windows and ROI manager
		selectWindow("Mask of dummy_cluster");
		close;
		selectWindow("Mask of dummy_signal");
		close;

	}

	// Clean up windows
	for(c = 1; c < (channels + 1); c++) {
		selectWindow("C" + c + "-" + image_title);
		close();
	}
	
	if(quant_nucl) {
		selectWindow("dummy_nucl");
		close;
	}
	
	if(quant_cell | remove_cluster | remove_signal) {
		selectWindow("dummy_marker");
		close;
	}
	
	selectWindow("dummy_cluster");
	close;
	selectWindow("dummy_signal");
	close;

}

selectWindow("ROI Manager");
run("Close");

// Check unique output file name and save
name_result_file_format = name_result_file + ".csv";
file_unique = false;
name_tracker = 0;
output_files = getFileList(outputfolder);

while(!file_unique) {
	check_list = newArray(output_files.length);
	for (j = 0; j < output_files.length; j++) {
		check_list[j] = (output_files[j] == name_result_file_format);
	}	
	Array.getStatistics(check_list, min, max, mean, stdDev);
	file_unique = (max == 0);
	if(!file_unique) {
		name_tracker = name_tracker + 1;
		name_result_file_format = name_result_file + "(" + name_tracker + ")" + ".csv";
	}
}

saveAs("Results", outputfolder + name_result_file_format);