// Compile System in Adam task
Adam("Cd(\"M:/System/\");\n");
AdamFile("M:/System/MakeSystem");

// Compile Slon in focused-on-boot User task
XTalkWait(Fs, "NetRep;\n");
XTalkWait(Fs, "TimeSync;\n");
XTalkWait(Fs, "Cd(\"M:/Slon/\");\n");
XTalkWait(Fs, "#include \"MakeSlon\";\n");
