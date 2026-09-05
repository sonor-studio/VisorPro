#!/bin/bash
sed -i '' 's/        \.navigationTitle("Bluetooth")/        \.formStyle(.grouped)\n        \.scrollContentBackground(.hidden)\n        \.navigationTitle("Bluetooth")/g' VisorPro/SettingsViews/BluetoothSettingsView.swift
