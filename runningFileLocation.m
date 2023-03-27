function folder = runningFileLocation
    folder = fileparts(matlab.desktop.editor.getActiveFilename);
    folder = [folder, '\'];
end