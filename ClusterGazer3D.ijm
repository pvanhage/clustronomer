// Input directories
inputfolder = getDirectory("Select a directory containing the raw files");
outputfolder = getDirectory("Select a directory to store the results");

// Input settings
Dialog.create("ClusterGazer 3D  v1.0.0-alpha");
  Dialog.addMessage("Input settings for ClusterGazer 3D");
  
  Dialog.addMessage("---------- Set channel number to match content ----------");
  Dialog.addNumber("Cluster channel", 1);
  Dialog.addNumber("Protein channel", 2);
  
  Dialog.addMessage("--------- Choose cluster ROI threshold method --------");
  Dialog.addChoice("Threshold method", newArray("Fixed value", "Set per image"));
  Dialog.addNumber("Minimum cluster size", 10);
  Dialog.addChoice("Units", newArray("voxel", "micron^3"));
  Dialog.addCheckbox("Remove extracellular cluster (whole-cell marker)", false);
  
  Dialog.addMessage("------------ Protein detection within cluster ROI ----------");
  Dialog.addChoice("Protein threshold", newArray("Fixed value", "Set per image"));
  Dialog.addNumber("Minimum protein size", 0);
  Dialog.addChoice("Units", newArray("voxel", "micron^3"));
  Dialog.addCheckbox("Remove extracellular protein (whole-cell marker)", false);
  
  Dialog.addMessage("------------------------ Quantify cell content -------------------");
  Dialog.addCheckbox("Whole-cell marker", false);
  Dialog.addCheckbox("Nuclei (Voronoi)", false);
  Dialog.addCheckbox("Protein foci", false);
  
  Dialog.addMessage("---------------------- Miscellaneous settings ----------------");
  Dialog.addString("Output file (.csv)", "Results");
  Dialog.addCheckbox("Guided mode", false);
  
  Dialog.show();
  
  c_cluster = Dialog.getNumber();
  c_prot = Dialog.getNumber();
  
  t_cluster = Dialog.getChoice();
  size_cluster = Dialog.getNumber();
  unit_cluster = Dialog.getChoice();
  remove_cluster = Dialog.getCheckbox();
  
  t_prot = Dialog.getChoice();
  size_prot = Dialog.getNumber();
  unit_prot = Dialog.getChoice();
  remove_prot = Dialog.getCheckbox();
  
  quant_cell = Dialog.getCheckbox();
  quant_nucl = Dialog.getCheckbox();
  quant_prot = Dialog.getCheckbox();
  
  
  name_result_file = Dialog.getString();
  guide_check = Dialog.getCheckbox();

// Whole-cell enumeration / extracellular cluster removal dialogue
if(quant_cell | remove_cluster | remove_prot) {
	
	Dialog.create("Settings whole-cell marker threshold");

	Dialog.addMessage("Settings marker threshold");
 	Dialog.addNumber("Marker channel", 1);
  	Dialog.addChoice("threshold method", newArray("Fixed value", "Set per image"));
  	Dialog.addNumber("Minimum cell size", 50);
  	Dialog.addChoice("Units", newArray("micron^3", "voxel"));
  	Dialog.addMessage("Filter to smooth image for thresholding");
  	Dialog.addNumber("Gaussian blur (micron)", 0.5);
  	Dialog.addCheckbox("Segment cells", false);
  
  	Dialog.show();
  
  	c_marker = Dialog.getNumber();
  	t_marker = Dialog.getChoice();
  	size_marker = Dialog.getNumber();
  	unit_marker = Dialog.getChoice();
  	gaus_marker = Dialog.getNumber();
  	split_cell = Dialog.getCheckbox();
  
}

// Nuclei segmentation dialogue
if(quant_nucl) {
	
	Dialog.create("Settings Nuclei (Voronoi)");

	Dialog.addMessage("Settings nuclei threshold");
 	Dialog.addNumber("Nuclei channel", 1);
  	Dialog.addChoice("threshold method", newArray("Fixed value", "Set per image"));
  	Dialog.addNumber("Minimum nuclei size", 10);
  	Dialog.addChoice("Units", newArray("micron^3", "voxel"));
  	Dialog.addMessage("Filter to smooth image for thresholding");
  	Dialog.addNumber("Gaussian blur (micron)", 0.5);
  	Dialog.addCheckbox("Segment nuclei", true);
	Dialog.addCheckbox("Voronoi segmentation (slow)", true);
  
  	Dialog.show();
  
  	c_nucl = Dialog.getNumber();
  	t_nucl = Dialog.getChoice();
  	size_nucl = Dialog.getNumber();
  	unit_nucl = Dialog.getChoice();
  	gaus_nucl = Dialog.getNumber();
  	split_nucl = Dialog.getCheckbox();
  	quant_voronoi = Dialog.getCheckbox();
  
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

// Load 3D manager
run("3D Manager");

// Loop through all files in the folder
for (l = 0; l < lengthOf(file_names); l++) {	
	
	// Open file, get metadata, and set global settings
	open(inputfolder + file_names[l]);
	getDimensions(width, height, channels, slices, frames);	
	getVoxelSize(vox_width, vox_height, vox_depth, vox_unit);
	total_px = width * height * slices;
	n_bit = bitDepth(); 
	max_greyval =  pow(2, n_bit) - 1;
	run("Options...", "iterations=1 count=1");
	image_title = file_names[l];
	run("Split Channels");
	
	// Convert units whole-cell marker 
	if(quant_cell | remove_cluster | remove_prot) {
		if (unit_marker == "micron^3") {
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
		if (unit_nucl == "micron^3") {
			size_nucl_px = size_nucl / (vox_width * vox_height * vox_depth);
			size_nucl_px = round(size_nucl_px);
			size_nucl_mu = size_nucl;
		} else {
			size_nucl_px = size_nucl;
			size_nucl_mu = size_nucl * (vox_width * vox_height * vox_depth);
		}	
	}
	
	// Convert units cluster ROI
	if (unit_cluster == "micron^3") {
		size_cluster_px = size_cluster / (vox_width * vox_height * vox_depth);
		size_cluster_px = round(size_cluster_px);
		size_cluster_mu = size_cluster;
	} else {
		size_cluster_px = size_cluster;
		size_cluster_mu = size_cluster * (vox_width * vox_height * vox_depth);
	}
	
	// Convert units protein ROI
	if (unit_prot == "micron^3") {
		size_prot_px = size_prot / (vox_width * vox_height * vox_depth);
		size_prot_px = round(size_prot_px);
		size_prot_mu = size_prot;
	} else {
		size_prot_px = size_prot;
		size_prot_mu = size_prot * (vox_width * vox_height * vox_depth);
	}
	
	// Process cell marker channel
	if(quant_cell | remove_cluster | remove_prot) {
		
		selectWindow("C" + c_marker + "-" + image_title);
		run("Duplicate...", "title=gaus_marker duplicate");
		selectWindow("gaus_marker");
		
		gaus_marker_x = gaus_marker / vox_width;
		gaus_marker_y = gaus_marker / vox_height;
		gaus_marker_z = gaus_marker / vox_depth;
		
		// Insert cell marker channel pre-threshold processing steps
		run("Gaussian Blur 3D...", "x="+ gaus_marker_x +" y="+ gaus_marker_y +" z="+ gaus_marker_z);
		// End of cell marker channel pre-threshold processing steps
		
		selectWindow("gaus_marker");
		run("Duplicate...", "title=dummy_marker duplicate");
		selectWindow("dummy_marker");
		
		if(t_marker == "Set per image") {
			
			min_auto = newArray(nSlices);
			max_auto = newArray(nSlices);
			for (i = 1; i < nSlices + 1; i++) {
				setSlice(i);
				setAutoThreshold("Huang dark");
				getThreshold(min_auto[i - 1], max_auto[i - 1]);
			}
			min_auto = Array.sort(min_auto);
			min_auto = min_auto[floor(min_auto.length/2)];
			max_auto = Array.sort(max_auto);
			max_auto = max_auto[floor(max_auto.length/2)];
			setSlice(1);
			setThreshold(min_auto, max_auto);

			run("Threshold...");
			getThreshold(MinThresh_marker, MaxThresh_marker);
			waitForUser("Set threshold for whole-cell marker per image. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
			getThreshold(MinThresh_marker, MaxThresh_marker);
			selectWindow("Threshold");
			run("Close");
			
		} else if (l == 0) {
			
			min_auto = newArray(nSlices);
			max_auto = newArray(nSlices);
			for (i = 1; i < nSlices + 1; i++) {
				setSlice(i);
				setAutoThreshold("Huang dark");
				getThreshold(min_auto[i - 1], max_auto[i - 1]);
			}
			min_auto = Array.sort(min_auto);
			min_auto = min_auto[floor(min_auto.length/2)];
			max_auto = Array.sort(max_auto);
			max_auto = max_auto[floor(max_auto.length/2)];
			setSlice(1);
			setThreshold(min_auto, max_auto);
			
			run("Threshold...");
			getThreshold(MinThresh_marker, MaxThresh_marker);
			waitForUser("Set a fixed threshold for whole-cell marker. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
			getThreshold(MinThresh_marker, MaxThresh_marker);
			selectWindow("Threshold");
			run("Close");
			
		}
		
		setThreshold(MinThresh_marker, MaxThresh_marker);
		run("Convert to Mask", "stack");
	
	}
	
	// Process nuclei channel
	if(quant_nucl) {
		
		selectWindow("C" + c_nucl + "-" + image_title);
		run("Duplicate...", "title=gaus_nucl duplicate");
		selectWindow("gaus_nucl");
		
		gaus_nucl_x = gaus_nucl / vox_width;
		gaus_nucl_y = gaus_nucl / vox_height;
		gaus_nucl_z = gaus_nucl / vox_depth;
		
		// Insert nuclei channel pre-threshold processing steps
		run("Gaussian Blur 3D...", "x="+ gaus_nucl_x +" y="+ gaus_nucl_y +" z="+ gaus_nucl_z);
		// End of nuclei channel pre-threshold processing steps
		
		selectWindow("gaus_nucl");
		run("Duplicate...", "title=dummy_nucl duplicate");
		selectWindow("dummy_nucl");
		
		if(t_nucl == "Set per image") {
			
			min_auto = newArray(nSlices);
			max_auto = newArray(nSlices);
			for (i = 1; i < nSlices + 1; i++) {
				setSlice(i);
				setAutoThreshold("Huang dark");
				getThreshold(min_auto[i - 1], max_auto[i - 1]);
			}
			min_auto = Array.sort(min_auto);
			min_auto = min_auto[floor(min_auto.length/2)];
			max_auto = Array.sort(max_auto);
			max_auto = max_auto[floor(max_auto.length/2)];
			setSlice(1);
			setThreshold(min_auto, max_auto);

			run("Threshold...");
			getThreshold(MinThresh_nucl, MaxThresh_nucl);
			waitForUser("Set threshold for cell nuclei per image. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
			getThreshold(MinThresh_nucl, MaxThresh_nucl);
			selectWindow("Threshold");
			run("Close");
			
		} else if (l == 0) {
			
			min_auto = newArray(nSlices);
			max_auto = newArray(nSlices);
			for (i = 1; i < nSlices + 1; i++) {
				setSlice(i);
				setAutoThreshold("Huang dark");
				getThreshold(min_auto[i - 1], max_auto[i - 1]);
			}
			min_auto = Array.sort(min_auto);
			min_auto = min_auto[floor(min_auto.length/2)];
			max_auto = Array.sort(max_auto);
			max_auto = max_auto[floor(max_auto.length/2)];
			setSlice(1);
			setThreshold(min_auto, max_auto);
			
			run("Threshold...");
			getThreshold(MinThresh_nucl, MaxThresh_nucl);
			waitForUser("Set a fixed threshold for cell nuclei. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
			getThreshold(MinThresh_nucl, MaxThresh_nucl);
			selectWindow("Threshold");
			run("Close");
			
		}
		
		setThreshold(MinThresh_nucl, MaxThresh_nucl);
		run("Convert to Mask", "stack");
	
	}	
	
	// Process cluster channel
	selectWindow("C" + c_cluster + "-" + image_title);
	run("Duplicate...", "title=dummy_cluster duplicate");
	selectWindow("dummy_cluster");
	
	// Insert cluster channel pre-threshold processing steps
	run("Smooth", "stack");
	// End of cluster channel pre-threshold processing steps
	
	if(t_cluster == "Set per image") {
		
		min_auto = newArray(nSlices);
		max_auto = newArray(nSlices);
		for (i = 1; i < nSlices + 1; i++) {
			setSlice(i);
			setAutoThreshold("Default dark");
			getThreshold(min_auto[i - 1], max_auto[i - 1]);
		}
		min_auto = Array.sort(min_auto);
		min_auto = min_auto[floor(min_auto.length/2)];
		max_auto = Array.sort(max_auto);
		max_auto = max_auto[floor(max_auto.length/2)];
		setSlice(1);
		setThreshold(min_auto, max_auto);
		
		run("Threshold...");
		getThreshold(MinThresh_cluster, MaxThresh_cluster);
		waitForUser("Set threshold cluster foci per image. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
		getThreshold(MinThresh_cluster, MaxThresh_cluster);
		selectWindow("Threshold");
		run("Close");
	
	} else if (l == 0) {

		min_auto = newArray(nSlices);
		max_auto = newArray(nSlices);
		for (i = 1; i < nSlices + 1; i++) {
			setSlice(i);
			setAutoThreshold("Default dark");
			getThreshold(min_auto[i - 1], max_auto[i - 1]);
		}
		min_auto = Array.sort(min_auto);
		min_auto = min_auto[floor(min_auto.length/2)];'
		max_auto = Array.sort(max_auto);
		max_auto = max_auto[floor(max_auto.length/2)];
		setSlice(1);
		setThreshold(min_auto, max_auto);
		
		run("Threshold...");
		getThreshold(MinThresh_cluster, MaxThresh_cluster);
		waitForUser("Set a fixed threshold for cluster foci. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
		getThreshold(MinThresh_cluster, MaxThresh_cluster);
		selectWindow("Threshold");
		run("Close");
	
	}
	
	setThreshold(MinThresh_cluster, MaxThresh_cluster);
	run("Convert to Mask", "stack");

	// Processing protein channel
	selectWindow("C" + c_prot + "-" + image_title);
	run("Duplicate...", "title=dummy_prot duplicate");
	selectWindow("dummy_prot");
	
	// Insert protein channel pre-threshold processing steps
	run("Smooth", "stack");
	// End of protein channel pre-threshold processing steps	
	
	if(t_prot == "Set per image") {
		
		min_auto = newArray(nSlices);
		max_auto = newArray(nSlices);
		for (i = 1; i < nSlices + 1; i++) {
			setSlice(i);
			setAutoThreshold("Yen dark");
			getThreshold(min_auto[i - 1], max_auto[i - 1]);
		}
		min_auto = Array.sort(min_auto);
		min_auto = min_auto[floor(min_auto.length/2)];
		max_auto = Array.sort(max_auto);
		max_auto = max_auto[floor(max_auto.length/2)];
		setSlice(1);
		setThreshold(min_auto, max_auto);
			
		run("Threshold...");
		getThreshold(MinThresh_prot, MaxThresh_prot);
		waitForUser("Set threshold protein foci per image. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
		getThreshold(MinThresh_prot, MaxThresh_prot);
		selectWindow("Threshold");
		run("Close");
	
	} else if (l == 0) {
			
		min_auto = newArray(nSlices);
		max_auto = newArray(nSlices);
		for (i = 1; i < nSlices + 1; i++) {
			setSlice(i);
			setAutoThreshold("Yen dark");
			getThreshold(min_auto[i - 1], max_auto[i - 1]);
		}
		min_auto = Array.sort(min_auto);
		min_auto = min_auto[floor(min_auto.length/2)];
		max_auto = Array.sort(max_auto);
		max_auto = max_auto[floor(max_auto.length/2)];
		setSlice(1);
		setThreshold(min_auto, max_auto);
		
		run("Threshold...");
		getThreshold(MinThresh_prot, MaxThresh_prot);
		waitForUser("Set a fixed threshold for protein foci. \nMove sliders and press OK when set.\n Do NOT press apply on the threshold menu.");
		getThreshold(MinThresh_prot, MaxThresh_prot);
		selectWindow("Threshold");
		run("Close");
		
	}
	
	setThreshold(MinThresh_prot, MaxThresh_prot);
	run("Convert to Mask", "stack");
	
	// Loop per time frame analzye add and quantify
	for(t = 1; t < (frames + 1); t++) {
		
		// Isolate clusters per frame and add to ROI manager
		selectWindow("dummy_cluster");
		Stack.setFrame(t);
		run("Duplicate...", "title=dummy_cluster_t" + t + " duplicate frames=" + t);
		
		// Isolate protein foci per frame 
		selectWindow("dummy_prot");
		Stack.setFrame(t);
		run("Duplicate...", "title=dummy_prot_t" + t + " duplicate frames=" + t);
		
		// Subtract cell marker from cluster and protein channels
		if(remove_cluster | remove_prot) {
			
			selectWindow("gaus_marker");
			Stack.setFrame(t);
			
			run("Duplicate...", "title=dummy_marker_t" + t + " duplicate frames=" + t);
			selectWindow("dummy_marker_t" + t);	
			run("3D Simple Segmentation", "seeds=None low_threshold=" + MinThresh_marker + " min_size=" + size_marker_px + " max_size=-1");
			
			selectWindow("Seg");
			seg_bit = bitDepth(); 
			seg_max = pow(2, seg_bit) - 1;
			setThreshold(1, seg_max);
			run("Convert to Mask", "stack");
			
			selectWindow("Bin");
			close();
			
			selectWindow("Seg");
			rename("cell_mask");
			
			selectWindow("cell_mask");
			mask_bit = bitDepth(); 
			mask_max = pow(2, mask_bit) - 1;
			setThreshold(1, mask_max);
			run("Convert to Mask", "stack");
			
			selectWindow("cell_mask");
			run("Invert", "stack");
			
			if(remove_cluster) imageCalculator("Subtract stack", "dummy_cluster_t" + t, "cell_mask");
			if(remove_prot)	imageCalculator("Subtract stack", "dummy_prot_t" + t, "cell_mask");
			
			selectWindow("dummy_marker_t" + t);
			close;
			selectWindow("cell_mask");
			close;
		
		}
		
		if((size_prot_px > 0) | quant_prot) {
			
			selectWindow("dummy_prot_t" + t);
			run("3D Simple Segmentation", "seeds=None low_threshold=1 min_size=" + size_prot_px + " max_size=-1");
			
			selectWindow("Bin");
			close();
			selectWindow("dummy_prot_t" + t);
			close();
			
			selectWindow("Seg");
			rename("dummy_prot_t" + t);	
			
			selectWindow("dummy_prot_t" + t);
			run("Duplicate...", "title=protein_segmented_t" + t + " duplicate");
			
			selectWindow("dummy_prot_t" + t);
			seg_bit = bitDepth(); 
			seg_max = pow(2, seg_bit) - 1;
			setThreshold(1, seg_max);
			run("Convert to Mask", "stack");
			
			if(!quant_prot) {
				selectWindow("protein_segmented_t" + t);
				close();
			}
			
		}
		
		selectWindow("dummy_cluster_t" + t);
		run("3D Simple Segmentation", "seeds=None low_threshold=1 min_size=" + size_cluster_px + " max_size=-1");
		selectWindow("Seg");
		Ext.Manager3D_AddImage();
		Ext.Manager3D_Count(n_cluster);
		
		// Demonstrate cluster ROIs
		if(guide_check & (l == 0) & (t == 1)) {
			
			selectWindow("C" + c_cluster + "-" + image_title);
			Stack.setFrame(t);
			run("Duplicate...", "title=cluster_intensities duplicate frames=" + t);
			Ext.Manager3D_Select(0);
			waitForUser("Example of cluster ROIs. \nPress OK to continue.");
			
			selectWindow("cluster_intensities");
			close();
		
		}
		
		selectWindow("Seg");
		close();
		selectWindow("dummy_cluster_t" + t);
		close();
		selectWindow("Bin");
		rename("dummy_cluster_t" + t);
		
		// Separate protein intensities per frame
		selectWindow("C" + c_prot + "-" + image_title);
		Stack.setFrame(t);
		run("Duplicate...", "title=protein_intensities_t" + t + " duplicate frames=" + t);
		
		// Demonstrate protein measurements within cluster ROIs
		if(guide_check & (l == 0) & (t == 1)) {
			
			selectWindow("protein_intensities_t" + t);
			Ext.Manager3D_Select(0);
			waitForUser("Example of protein intensities measured by cluster ROIs. \nPress OK to continue.");
			
		}
		
		// Summarize cluster and protein content
		if(n_cluster > 0) {
			
			selectWindow("protein_intensities_t" + t);
			
			for (b = 0; b < n_cluster; b++) {
				
				Ext.Manager3D_Measure3D(b, "Vol", cluster_vol);
				Ext.Manager3D_Quantif3D(b, "Mean", cluster_mean);
				Ext.Manager3D_Quantif3D(b, "IntDen", cluster_intden);
				Ext.Manager3D_Quantif3D(b, "Min", cluster_min);
				Ext.Manager3D_Quantif3D(b, "Max", cluster_max);
				Ext.Manager3D_Quantif3D(b, "Sigma", cluster_sd);
				Ext.Manager3D_Centroid3D(b, cluster_x, cluster_y, cluster_z);
				
				Table.set("Label", obj_ind, image_title);
				Table.set("Object", obj_ind, "Cluster");
				Table.set("Volume", obj_ind, cluster_vol);
				Table.set("X", obj_ind, cluster_x);
				Table.set("Y", obj_ind, cluster_y);
				Table.set("Z", obj_ind, cluster_z);
				Table.set("T", obj_ind, t);
				Table.set("Mean", obj_ind, cluster_mean);
				Table.set("IntDen", obj_ind, cluster_intden);
				Table.set("Min", obj_ind, cluster_min);
				Table.set("Max", obj_ind, cluster_max);
				Table.set("Sigma", obj_ind, cluster_sd);
				
				obj_ind = obj_ind + 1;
			}
			
			// Calculate protein fraction per cluster
			selectWindow("dummy_prot_t" + t);
			
			for (b = 0; b < n_cluster; b++) {
			
				Ext.Manager3D_Quantif3D(b, "Mean", prot_frac_bit);
				prot_frac = (prot_frac_bit / max_greyval);
				
				Table.set("FractionProtein", obj_ind_frac, prot_frac);
				Table.set("FractionCluster", obj_ind_frac, 1);
				Table.set("MinThreshObject", obj_ind_frac, MinThresh_cluster);
				Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_cluster);
				Table.set("MinThreshProtein", obj_ind_frac, MinThresh_prot);
				Table.set("MaxThreshProtein", obj_ind_frac, MaxThresh_prot);
				
				obj_ind_frac = obj_ind_frac + 1;
			}
		 
		}
		
		Ext.Manager3D_Reset();
		
		// Quantify cell content
		if(quant_cell) {
				
			selectWindow("gaus_marker");
			Stack.setFrame(t);
			
			run("Duplicate...", "title=dummy_marker_t" + t + " duplicate frames=" + t);
			selectWindow("dummy_marker_t" + t);
			
			if(split_cell) {
				
				run("3D Nuclei Segmentation", "auto_threshold=Default manual=" + MinThresh_marker + " separate_nuclei");
				selectWindow("merge");
				run("3D Simple Segmentation", "seeds=None low_threshold=1 min_size=" + size_marker_px + " max_size=-1");
				
				selectWindow("merge");
				close();
			
			} else {
				
				run("3D Simple Segmentation", "seeds=None low_threshold="+ MinThresh_marker + " min_size=" + size_marker_px + " max_size=-1");
			}
			
			selectWindow("Bin");
			close();
			
			selectWindow("Seg");
			Ext.Manager3D_AddImage();
			Ext.Manager3D_Count(n_cell);
			
			selectWindow("Seg");
			close();
			
			// Demonstrate cell ROIs
			if(guide_check & (l == 0) & (t == 1)) {
				
				selectWindow("C" + c_marker + "-" + image_title);
				Stack.setFrame(t);
				run("Duplicate...", "title=marker_intensities duplicate frames=" + t);
				Ext.Manager3D_Select(0);
				waitForUser("Example of cell ROIs. \nPress OK to continue.");
				
				selectWindow("marker_intensities");
				close();		
			
			}		
			
			// Summarize cell and protein content
			if(n_cell > 0) {
				
				selectWindow("protein_intensities_t" + t);
				
				for (b = 0; b < n_cell; b++) {
					
					Ext.Manager3D_Measure3D(b, "Vol", cell_vol);
					Ext.Manager3D_Quantif3D(b, "Mean", cell_mean);
					Ext.Manager3D_Quantif3D(b, "IntDen", cell_intden);
					Ext.Manager3D_Quantif3D(b, "Min", cell_min);
					Ext.Manager3D_Quantif3D(b, "Max", cell_max);
					Ext.Manager3D_Quantif3D(b, "Sigma", cell_sd);
					Ext.Manager3D_Centroid3D(b, cell_x, cell_y, cell_z);
					
					Table.set("Label", obj_ind, image_title);
					Table.set("Object", obj_ind, "Cell");
					Table.set("Volume", obj_ind, cell_vol);
					Table.set("X", obj_ind, cell_x);
					Table.set("Y", obj_ind, cell_y);
					Table.set("Z", obj_ind, cell_z);
					Table.set("T", obj_ind, t);
					Table.set("Mean", obj_ind, cell_mean);
					Table.set("IntDen", obj_ind, cell_intden);
					Table.set("Min", obj_ind, cell_min);
					Table.set("Max", obj_ind, cell_max);
					Table.set("Sigma", obj_ind, cell_sd);
					
					obj_ind = obj_ind + 1;
				}
				
				// Calculate protein fraction per cell
				selectWindow("dummy_prot_t" + t);
				
				for (b = 0; b < n_cell; b++) {
				
					Ext.Manager3D_Quantif3D(b, "Mean", prot_frac_bit);
					prot_frac = (prot_frac_bit / max_greyval);
					
					Table.set("FractionProtein", obj_ind_frac, prot_frac);
					Table.set("MinThreshObject", obj_ind_frac, MinThresh_marker);
					Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_marker);
					Table.set("MinThreshProtein", obj_ind_frac, MinThresh_prot);
					Table.set("MaxThreshProtein", obj_ind_frac, MaxThresh_prot);
					
					obj_ind_frac = obj_ind_frac + 1;
				
				}
				
				// Calculate cluster fraction per cell
				selectWindow("dummy_cluster_t" + t);
				obj_ind_frac = obj_ind_frac - n_cell;
				
				for (b = 0; b < n_cell; b++) {
				
					Ext.Manager3D_Quantif3D(b, "Mean", cluster_frac_bit);
					cluster_frac = (cluster_frac_bit / max_greyval);
					Table.set("FractionCluster", obj_ind_frac, cluster_frac);
					
					obj_ind_frac = obj_ind_frac + 1;
				
				}
				
			}
			
			selectWindow("dummy_marker_t" + t);
			close();
			
			Ext.Manager3D_Reset();
			
		}
		
		if(quant_nucl) {

			selectWindow("gaus_nucl");
			Stack.setFrame(t);
			
			run("Duplicate...", "title=dummy_nucl_t" + t + " duplicate frames=" + t);
			selectWindow("dummy_nucl_t" + t);
			
			if(split_nucl) {
				
				run("3D Nuclei Segmentation", "auto_threshold=Default manual=" + MinThresh_nucl + " separate_nuclei");
				selectWindow("merge");
				run("3D Simple Segmentation", "seeds=None low_threshold=1 min_size=" + size_nucl_px + " max_size=-1");
				
				selectWindow("merge");
				close();
				
			} else {
				
				run("3D Simple Segmentation", "seeds=None low_threshold=" + MinThresh_nucl + " min_size=" + size_nucl_px + " max_size=-1");
			}
			
			selectWindow("Bin");
			close();
			
			selectWindow("Seg");
			Ext.Manager3D_AddImage();
			Ext.Manager3D_Count(n_nucl);
			
			if(n_nucl > 0) {

				selectWindow("protein_intensities_t" + t);
				
				for (b = 0; b < n_nucl; b++) {
					
					Ext.Manager3D_Measure3D(b, "Vol", nucl_vol);
					Ext.Manager3D_Quantif3D(b, "Mean", nucl_mean);
					Ext.Manager3D_Quantif3D(b, "IntDen", nucl_intden);
					Ext.Manager3D_Quantif3D(b, "Min", nucl_min);
					Ext.Manager3D_Quantif3D(b, "Max", nucl_max);
					Ext.Manager3D_Quantif3D(b, "Sigma", nucl_sd);
					Ext.Manager3D_Centroid3D(b, nucl_x, nucl_y, nucl_z);
					
					Table.set("Label", obj_ind, image_title);
					Table.set("Object", obj_ind, "Nucleus");
					Table.set("Volume", obj_ind, nucl_vol);
					Table.set("X", obj_ind, nucl_x);
					Table.set("Y", obj_ind, nucl_y);
					Table.set("Z", obj_ind, nucl_z);
					Table.set("T", obj_ind, t);
					Table.set("Mean", obj_ind, nucl_mean);
					Table.set("IntDen", obj_ind, nucl_intden);
					Table.set("Min", obj_ind, nucl_min);
					Table.set("Max", obj_ind, nucl_max);
					Table.set("Sigma", obj_ind, nucl_sd);
					
					obj_ind = obj_ind + 1;
				}
				
				// Calculate protein fraction per nuclei
				selectWindow("dummy_prot_t" + t);
				
				for (b = 0; b < n_nucl; b++) {
				
					Ext.Manager3D_Quantif3D(b, "Mean", prot_frac_bit);
					prot_frac = (prot_frac_bit / max_greyval);
					
					Table.set("FractionProtein", obj_ind_frac, prot_frac);
					Table.set("MinThreshObject", obj_ind_frac, MinThresh_nucl);
					Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_nucl);
					Table.set("MinThreshProtein", obj_ind_frac, MinThresh_prot);
					Table.set("MaxThreshProtein", obj_ind_frac, MaxThresh_prot);
					
					obj_ind_frac = obj_ind_frac + 1;
				
				}
				
				// Calculate cluster fraction per nuclei
				selectWindow("dummy_cluster_t" + t);
				obj_ind_frac = obj_ind_frac - n_nucl;
				
				for (b = 0; b < n_nucl; b++) {
				
					Ext.Manager3D_Quantif3D(b, "Mean", cluster_frac_bit);
					cluster_frac = (cluster_frac_bit / max_greyval);
					Table.set("FractionCluster", obj_ind_frac, cluster_frac);
					
					obj_ind_frac = obj_ind_frac + 1;
				
				}
			
				Ext.Manager3D_Reset();
				
				// Create and quantify 3D Voronoi
				if(quant_voronoi) {
					
					selectWindow("Seg");
					run("3D Watershed Voronoi", "radius_max=0");
					Ext.Manager3D_AddImage();
					Ext.Manager3D_Count(n_voronoi);
						
					if(n_voronoi > 0) {
						
						selectWindow("protein_intensities_t" + t);
						
						for (b = 0; b < n_voronoi; b++) {
							
							Ext.Manager3D_Measure3D(b, "Vol", voronoi_vol);
							Ext.Manager3D_Quantif3D(b, "Mean", voronoi_mean);
							Ext.Manager3D_Quantif3D(b, "IntDen", voronoi_intden);
							Ext.Manager3D_Quantif3D(b, "Min", voronoi_min);
							Ext.Manager3D_Quantif3D(b, "Max", voronoi_max);
							Ext.Manager3D_Quantif3D(b, "Sigma", voronoi_sd);
							Ext.Manager3D_Centroid3D(b, voronoi_x, voronoi_y, voronoi_z);
							
							Table.set("Label", obj_ind, image_title);
							Table.set("Object", obj_ind, "Voronoi");
							Table.set("Volume", obj_ind, voronoi_vol);
							Table.set("X", obj_ind, voronoi_x);
							Table.set("Y", obj_ind, voronoi_y);
							Table.set("Z", obj_ind, voronoi_z);
							Table.set("T", obj_ind, t);
							Table.set("Mean", obj_ind, voronoi_mean);
							Table.set("IntDen", obj_ind, voronoi_intden);
							Table.set("Min", obj_ind, voronoi_min);
							Table.set("Max", obj_ind, voronoi_max);
							Table.set("Sigma", obj_ind, voronoi_sd);
							
							obj_ind = obj_ind + 1;
						}
						
						// Calculate protein fraction per voronoi
						selectWindow("dummy_prot_t" + t);
						
						for (b = 0; b < n_voronoi; b++) {
						
							Ext.Manager3D_Quantif3D(b, "Mean", prot_frac_bit);
							prot_frac = (prot_frac_bit / max_greyval);
							
							Table.set("FractionProtein", obj_ind_frac, prot_frac);
							Table.set("MinThreshObject", obj_ind_frac, MinThresh_nucl);
							Table.set("MaxThreshObject", obj_ind_frac, MaxThresh_nucl);
							Table.set("MinThreshProtein", obj_ind_frac, MinThresh_prot);
							Table.set("MaxThreshProtein", obj_ind_frac, MaxThresh_prot);
							
							obj_ind_frac = obj_ind_frac + 1;
						
						}
						
						// Calculate cluster fraction per voronoi
						selectWindow("dummy_cluster_t" + t);
						obj_ind_frac = obj_ind_frac - n_voronoi;
						
						for (b = 0; b < n_voronoi; b++) {
						
							Ext.Manager3D_Quantif3D(b, "Mean", cluster_frac_bit);
							cluster_frac = (cluster_frac_bit / max_greyval);
							Table.set("FractionCluster", obj_ind_frac, cluster_frac);
							
							obj_ind_frac = obj_ind_frac + 1;
						
						}					
						
					}
						
					selectWindow("VoronoiZones");
					close();
				
				}
			}
			
			selectWindow("Seg");
			close();
			
			selectWindow("dummy_nucl_t" + t);
			close();
				
			Ext.Manager3D_Reset();
			
		}
		
		if(quant_prot) {
			
			selectWindow("protein_segmented_t" + t);
			Ext.Manager3D_AddImage();
			Ext.Manager3D_Count(n_prot);
			
			if(n_prot > 0) {
				
				selectWindow("protein_intensities_t" + t);

				for (b = 0; b < n_prot; b++) {
					
					Ext.Manager3D_Measure3D(b, "Vol", prot_vol);
					Ext.Manager3D_Quantif3D(b, "Mean", prot_mean);
					Ext.Manager3D_Quantif3D(b, "IntDen", prot_intden);
					Ext.Manager3D_Quantif3D(b, "Min", prot_min);
					Ext.Manager3D_Quantif3D(b, "Max", prot_max);
					Ext.Manager3D_Quantif3D(b, "Sigma", prot_sd);
					Ext.Manager3D_Centroid3D(b, prot_x, prot_y, prot_z);
					
					Table.set("Label", obj_ind, image_title);
					Table.set("Object", obj_ind, "Protein");
					Table.set("Volume", obj_ind, prot_vol);
					Table.set("X", obj_ind, prot_x);
					Table.set("Y", obj_ind, prot_y);
					Table.set("Z", obj_ind, prot_z);
					Table.set("T", obj_ind, t);
					Table.set("Mean", obj_ind, prot_mean);
					Table.set("IntDen", obj_ind, prot_intden);
					Table.set("Min", obj_ind, prot_min);
					Table.set("Max", obj_ind, prot_max);
					Table.set("Sigma", obj_ind, prot_sd);
					
					Table.set("FractionProtein", obj_ind, 1);
					Table.set("MinThreshObject", obj_ind, MinThresh_prot);
					Table.set("MaxThreshObject", obj_ind, MaxThresh_prot);
					Table.set("MinThreshProtein", obj_ind, MinThresh_prot);
					Table.set("MaxThreshProtein", obj_ind, MaxThresh_prot);
					
					obj_ind = obj_ind + 1;
				}
				
				// Calculate cluster fraction per protein focus
				selectWindow("dummy_cluster_t" + t);
				
				for (b = 0; b < n_prot; b++) {
				
					Ext.Manager3D_Quantif3D(b, "Mean", cluster_frac_bit);
					cluster_frac = (cluster_frac_bit / max_greyval);
					Table.set("FractionCluster", obj_ind_frac, cluster_frac);
					
					obj_ind_frac = obj_ind_frac + 1;
				
				}

			}
			
			selectWindow("protein_segmented_t" + t);
			close();
			
			Ext.Manager3D_Reset();
		
		}
		
		// Reset windows per frame
		selectWindow("dummy_cluster_t" + t);
		close();
		
		selectWindow("dummy_prot_t" + t);
		close();
		
		selectWindow("protein_intensities_t" + t);
		close();
		
	}

	// Clean up windows
	for(c = 1; c < (channels + 1); c++) {
		selectWindow("C" + c + "-" + image_title);
		close();
	}

	if(quant_cell | remove_cluster | remove_prot) {
		selectWindow("gaus_marker");
		close;
		selectWindow("dummy_marker");
		close;
	}
	
	
	if(quant_nucl) {
		selectWindow("gaus_nucl");
		close;
		selectWindow("dummy_nucl");
		close;
	}
	
	selectWindow("dummy_cluster");
	close;
	selectWindow("dummy_prot");
	close;
}

Ext.Manager3D_Close();

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