# Reparo de relação de confiança entre estação de trabalho e o domínio
# Script pode ser utilizado tanto por GPO quanto por SCCM
# Script by Eduardo Popovici

# Set-ExecutionPolicy Unrestricted - Use com moderação
# Get-ExecutionPolicy - Valida qual é a permissão atual de execução de scrpts no equipamento

# Reparo de relação de confiança
# Set-ExecutionPolicy Unrestricted
# Get-ExecutionPolicy

Clear

# Coleta e modificação do timestamp
# ${time-stamp} = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }

# Coleta o último logon
# Get-ADUser pcontreras -Properties lastLogon | Select samaccountname, @{Name="lastLogon";Expression={[datetime]::FromFileTime($_.'lastLogon')}}

# Coleta da data atual
${data-atual} = (Get-Date).Date

# Verificação do estado do canal seguro com o domínio
${test-channel} = test-computersecurechannel -verbose

# ${reset-channel} = Reset-ComputerMachinePassword
# ${Time-test} Get-ADComputer -Filter 'createTimeStamp -ge $data-atual' -Properties createTimeStamp

if(${test-channel} -eq "True" ){
    Write-Output "Relação de confiança validada em ${data-atual}"
    # Write-Output "Timestamp atual ${time-stamp}"
    }	
    Else
    { 
    test-computersecurechannel -repair -verbose
    }
