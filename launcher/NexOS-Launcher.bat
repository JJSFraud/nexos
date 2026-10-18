@echo off
title NexOS Launcher & Installer v2.0
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "%~dp0NexOS-Launcher.ps1"
