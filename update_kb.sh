#!/bin/bash
sed -i '' 's/ScrollView {/Form {/g' VisorPro/SettingsViews/KeyboardBrightnessSettingsView.swift
sed -i '' 's/            VStack(spacing: 24) {//g' VisorPro/SettingsViews/KeyboardBrightnessSettingsView.swift
sed -i '' 's/        \.navigationTitle("Keyboard Brightness")/        \.formStyle(.grouped)\n        \.scrollContentBackground(.hidden)\n        \.navigationTitle("Keyboard Brightness")/g' VisorPro/SettingsViews/KeyboardBrightnessSettingsView.swift
