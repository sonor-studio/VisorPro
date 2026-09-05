#!/bin/bash
sed -i '' 's/ScrollView {/Form {/g' VisorPro/SettingsViews/FeedbackSettingsView.swift
sed -i '' 's/            VStack(spacing: 24) {//g' VisorPro/SettingsViews/FeedbackSettingsView.swift
sed -i '' 's/            \.padding()//g' VisorPro/SettingsViews/FeedbackSettingsView.swift
sed -i '' 's/        \.navigationTitle("Feedback")/        \.formStyle(.grouped)\n        \.scrollContentBackground(.hidden)\n        \.navigationTitle("Feedback")/g' VisorPro/SettingsViews/FeedbackSettingsView.swift
