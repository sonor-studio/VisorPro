#!/bin/bash
sed -i '' 's/ScrollView {/Form {/g' VisorPro/SettingsViews/BluetoothSettingsView.swift
sed -i '' 's/            VStack(spacing: 24) {//g' VisorPro/SettingsViews/BluetoothSettingsView.swift
