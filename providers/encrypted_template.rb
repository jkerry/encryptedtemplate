action :create do
	path = new_resource.path
	source = new_resource.source
	variables = new_resource.variables
	section_name = new_resource.section_name
	surround_with_config_root = new_resource.surround_with_config_root

	if false #TODO: use currentresource guard
		Chef::Log.info "#{@new_resource} is already templated and encrypted."
	else
		require 'securerandom'
		temporary_filepath = "#{Chef::Config['file_cache_path']}/#{SecureRandom.uuid}.temporary.erb"
		template temporary_filepath do
			source source
			variables variables
		end

		if surround_with_config_root
			powershell_script "Surround with configuration root" do
				code <<-EOH
					$configFilePath = "#{temporary_filepath}"
					$content = (Get-Content $configFilePath)
					Set-Content -path $configFilePath -value "<configuration>$content</configuration>"
				EOH
			end
		end

		powershell_script "Encrypt temporary config file" do
			code <<-EOH
				$configFilePath = "#{temporary_filepath}"
				$sectionName = "#{section_name}"
				$dataProtectionProvider = "DataProtectionConfigurationProvider"

				#The System.Configuration assembly must be loaded
				$configurationAssembly = "System.Configuration, Version=2.0.0.0, Culture=Neutral, PublicKeyToken=b03f5f7f11d50a3a"
				[void] [Reflection.Assembly]::Load($configurationAssembly)

				$configurationFileMap = New-Object -TypeName System.Configuration.ExeConfigurationFileMap
				$configurationFileMap.ExeConfigFilename = $configFilePath
				$configuration = [System.Configuration.ConfigurationManager]::OpenMappedExeConfiguration($configurationFileMap, [System.Configuration.ConfigurationUserLevel]"None")
				$section = $configuration.GetSection($sectionName)

				if (-not $section.SectionInformation.IsProtected)
				{
					Write-Host "Encrypting configuration section..."
					$section.SectionInformation.ProtectSection($dataProtectionProvider);
					$section.SectionInformation.ForceSave = [System.Boolean]::True;
					$configuration.Save([System.Configuration.ConfigurationSaveMode]::Modified);
					Write-Host "Succeeded!"
				}
			EOH
		end

		if surround_with_config_root
			powershell_script "remove configuration root" do
				code <<-EOH
					function Format-XML ([xml]$xml, $indent=2)
					{
						$StringWriter = New-Object System.IO.StringWriter
						$XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
						$xmlWriter.Formatting = "indented"
						$xmlWriter.Indentation = $Indent
						$xml.WriteContentTo($XmlWriter)
						$XmlWriter.Flush()
						$StringWriter.Flush()
						return $StringWriter.ToString()
					}

					$configFilePath = "#{temporary_filepath}"
					$content = (Get-Content $configFilePath)
					$content = ([string]$content).Replace("<configuration>","")
					$content = ([string]$content).Replace("</configuration>","")
					$content = Format-XML -xml $content
					Set-Content -path $configFilePath -value $content
				EOH
			end
		end

		template path do
			source temporary_filepath
			variables variables
			local true
		end

		# file temporary_filepath do
		# 	action :delete
		# end

	end
end
