                        if isDrive {
                            if let total = driveTotalSpace, let freeStr = driveFreeSpace, let rawTotal = rawDriveTotal, let rawFree = rawDriveFree, rawTotal > 0 {
                                let totalBytes = Double(rawTotal)
                                let freeBytes = Double(rawFree)
                                let usedBytes = totalBytes - freeBytes
                                let percentage = usedBytes / totalBytes
                                
                                VStack(spacing: 12) {
                                    let tint: Color = actionColor
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .lastTextBaseline) {
                                            Text(total)
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text("\(freeStr) free")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color.primary.opacity(0.1))
                                                    .frame(height: 6)
                                                
                                                Capsule()
                                                    .fill(tint)
                                                    .frame(width: max(0, geo.size.width * min(percentage, 1.0)), height: 6)
                                            }
                                        }
                                        .frame(height: 6)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 4)
                                }
                            } else if isConnected && !isEjected {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .lastTextBaseline) {
                                        if isOpticalEmpty {
                                            Text("No Media Inserted")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("Calculating size...")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            ProgressView()
                                                .scaleEffect(0.5)
                                                .frame(width: 12, height: 12)
                                        }
                                    }
                                    
                                    Capsule()
                                        .fill(Color.primary.opacity(0.1))
                                        .frame(height: 6)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 4)
                            }
                        }
