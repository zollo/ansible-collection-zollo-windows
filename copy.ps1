$base = "C:\Github"
$src_repo = "ansible-collection-windows-server"
$dst_repo = "community.windows"
$module = "win_dns_zone"
Copy-Item -Path "$base\$src_repo\tests\integration\targets\$module" -Recurse -Destination "$base\$dst_repo\tests\integration\targets\" -Force
Copy-Item -Path "$base\$src_repo\plugins\modules\$module.ps1" -Destination "$base\$dst_repo\plugins\modules\$module.ps1" -Force
Copy-Item -Path "$base\$src_repo\plugins\modules\$module.py" -Destination "$base\$dst_repo\plugins\modules\$module.py" -Force
