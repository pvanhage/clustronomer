// Get file extension
Dialog.create("Separate image series");
	
	Dialog.addMessage("Separate image series into TIFF files");
	
	Dialog.addMessage("---------- Input extension of image series ---------");
	Dialog.addString("File extension", ".lif");

Dialog.show();

	ind_extension = Dialog.getString();

// Select directories
inputfolder = getDirectory("Select a directory consisting of " + ind_extension + " files.");
outputfolder = getDirectory("Select a directory to store seperated " + ind_extension + " files.");

// get file list
file_list = getFileList(inputfolder);
file_counter = 0;
series_counter = 0;

// Separate series using Bio-Formats
setBatchMode(true);
run("Bio-Formats Macro Extensions");

for(i = 0; i < file_list.length; i++) {
	
	if(endsWith(file_list[i], ind_extension)) {
		
		select_file = inputfolder + file_list[i];
		
		Ext.setId(select_file);
		Ext.getSeriesCount(seriesCount);
		print("Identified " + seriesCount + " series in " + select_file + ".");
		series_counter = series_counter + seriesCount;
		
		// Process series
		for (l = 0; l < seriesCount; l++) {
			
			// Open individual image from series
			image_ind = l + 1;
			run("Bio-Formats Importer", "open=[" + select_file + "] color_mode=Default view=Hyperstack stack_order=XYCZT series_" + image_ind);
			raw_title	= getTitle();
			image_title = substring(raw_title, lastIndexOf(raw_title, " - ") + 3, lengthOf(raw_title));
			
			// Check if file name is unique
			image_title_format = image_title + ".tif";
			image_title_unique = false;
			name_tracker = 0;
			output_files = getFileList(outputfolder);
			
			while(!image_title_unique) {
				
				unique_files = newArray(lengthOf(output_files));
				
				for (j = 0; j < lengthOf(output_files); j++) {
					unique_files[j] = (output_files[j] == image_title_format);
				}	
				
				Array.getStatistics(unique_files, min, max, mean, stdDev);
				image_title_unique = (max == 0);

				if(!image_title_unique) {
					
					name_tracker = name_tracker + 1;
					image_title_format = image_title + "_" + name_tracker + ".csv";
				}
			}
			
			// Save as separate TIFF file
			saveAs("tiff", outputfolder + File.separator + image_title_format);
			print("Saved " + image_title + " in " + outputfolder + ".");
			close();
		}
		
		file_counter = file_counter + 1;
	}
}

setBatchMode(false);
showMessage("Processed " + file_counter + " files for a total of " + series_counter + " series.");
