#!/bin/bash
# Remove plus icons in SettingsView
sed -i '' 's/if savedLicenseKey.isEmpty { Image(systemName: "plus").foregroundColor(.secondary).font(.caption2) } //g' VisorPro/SettingsViews/SettingsView.swift
sed -i '' 's/if savedLicenseKey.isEmpty { Image(systemName: "sparkles").foregroundColor(.indigo).font(.caption2) } //g' VisorPro/SettingsViews/SettingsView.swift
