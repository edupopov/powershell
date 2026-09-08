;WITH CPU AS
(
    SELECT
        ResourceID,
        MAX(Manufacturer0) AS FabricanteCPU,
        MAX(Name0) AS ModeloCPU,
        COUNT(*) AS QuantidadeCPUs,
        SUM(ISNULL(NumberOfCores0, 0)) AS TotalNucleos,
        SUM(ISNULL(NumberOfLogicalProcessors0, 0)) AS TotalProcessadoresLogicos
    FROM v_GS_PROCESSOR
    GROUP BY ResourceID
),

RAM AS
(
    SELECT
        ResourceID,

        -- Capacity0 está sendo reportado em MB no seu inventário
        SUM(CAST(Capacity0 AS BIGINT)) AS TotalMemoryMB,

        COUNT(*) AS QuantidadeModulosRAM,

        MIN(Speed0) AS VelocidadeMinimaRAM_MHz,
        MAX(Speed0) AS VelocidadeMaximaRAM_MHz,

        MAX(Manufacturer0) AS FabricanteRAM

    FROM v_GS_PHYSICAL_MEMORY
    GROUP BY ResourceID
),

REDE AS
(
    SELECT
        ResourceID,
        MAX(IPAddress0) AS IPAddress0,
        MAX(MACAddress0) AS MACAddress0
    FROM v_GS_NETWORK_ADAPTER_CONFIGUR
    WHERE IPEnabled0 = 1
      AND MACAddress0 IS NOT NULL
    GROUP BY ResourceID
)

SELECT

    ----------------------------------------------------------------
    -- IDENTIFICAÇÃO DO EQUIPAMENTO
    ----------------------------------------------------------------

    rs.ResourceID,

    rs.Name0 AS NomeComputador,

    rs.User_Name0 AS UltimoUsuario,

    rs.Client0 AS ClienteSCCM,

    rs.Active0 AS Ativo,

    rs.Obsolete0 AS Obsoleto,

    rs.Last_Logon_Timestamp0 AS UltimoLogon,


    ----------------------------------------------------------------
    -- SISTEMA OPERACIONAL
    ----------------------------------------------------------------

    os.Caption0 AS SistemaOperacional,

    os.Version0 AS VersaoSistemaOperacional,


    ----------------------------------------------------------------
    -- FABRICANTE / MODELO
    ----------------------------------------------------------------

    cs.Manufacturer0 AS Fabricante,

    cs.Model0 AS Modelo,


    ----------------------------------------------------------------
    -- MEMÓRIA RAM
    ----------------------------------------------------------------

    CAST(
        ram.TotalMemoryMB / 1024.0
        AS DECIMAL(10,2)
    ) AS MemoriaRAM_GB,

    ram.QuantidadeModulosRAM,

    ram.VelocidadeMinimaRAM_MHz,

    ram.VelocidadeMaximaRAM_MHz,

    ram.FabricanteRAM,


    ----------------------------------------------------------------
    -- PROCESSADOR
    ----------------------------------------------------------------

    cpu.FabricanteCPU,

    cpu.ModeloCPU,

    cpu.QuantidadeCPUs,

    cpu.TotalNucleos,

    cpu.TotalProcessadoresLogicos,


    ----------------------------------------------------------------
    -- BIOS
    ----------------------------------------------------------------

    bios.SerialNumber0 AS NumeroSerie,

    bios.SMBIOSBIOSVersion0 AS VersaoBIOS,

    bios.ReleaseDate0 AS DataBIOS,


    ----------------------------------------------------------------
    -- TPM
    ----------------------------------------------------------------

    CASE
        WHEN tpm.ResourceID IS NOT NULL THEN 'Sim'
        ELSE 'Não'
    END AS PossuiTPM,

    tpm.SpecVersion0 AS VersaoTPM,

    tpm.ManufacturerVersion0 AS VersaoFirmwareTPM,

    CASE
        WHEN tpm.IsEnabled_InitialValue0 = 1 THEN 'Sim'
        WHEN tpm.IsEnabled_InitialValue0 = 0 THEN 'Não'
        ELSE 'Desconhecido'
    END AS TPMHabilitado,

    CASE
        WHEN tpm.IsActivated_InitialValue0 = 1 THEN 'Sim'
        WHEN tpm.IsActivated_InitialValue0 = 0 THEN 'Não'
        ELSE 'Desconhecido'
    END AS TPMAtivado,

    CASE
        WHEN tpm.IsOwned_InitialValue0 = 1 THEN 'Sim'
        WHEN tpm.IsOwned_InitialValue0 = 0 THEN 'Não'
        ELSE 'Desconhecido'
    END AS TPMOwned,


    ----------------------------------------------------------------
    -- REDE
    ----------------------------------------------------------------

    net.IPAddress0 AS EnderecoIP,

    net.MACAddress0 AS EnderecoMAC,


    ----------------------------------------------------------------
    -- DISCO C:
    ----------------------------------------------------------------

    CAST(
        disk.Size0 / 1024.0
        AS DECIMAL(12,2)
    ) AS DiscoC_Total_GB,

    CAST(
        disk.FreeSpace0 / 1024.0
        AS DECIMAL(12,2)
    ) AS DiscoC_Livre_GB,

    CASE
        WHEN disk.Size0 > 0 THEN
            CAST(
                (disk.FreeSpace0 * 100.0) / disk.Size0
                AS DECIMAL(6,2)
            )
        ELSE NULL
    END AS DiscoC_PercentualLivre,


    ----------------------------------------------------------------
    -- BITLOCKER
    ----------------------------------------------------------------

    bit.ProtectionStatus0 AS BitLockerProtectionStatus,

    CASE
        WHEN bit.ProtectionStatus0 = 0 THEN 'Proteção Desabilitada'
        WHEN bit.ProtectionStatus0 = 1 THEN 'Proteção Habilitada'
        WHEN bit.ProtectionStatus0 = 2 THEN 'Status Desconhecido'
        ELSE 'Não Informado'
    END AS StatusBitLocker,


    ----------------------------------------------------------------
    -- CHASSI
    ----------------------------------------------------------------

    se.ChassisTypes0 AS TipoChassi,


    ----------------------------------------------------------------
    -- ÚLTIMO INVENTÁRIO SCCM
    ----------------------------------------------------------------

    hw.LastHWScan AS UltimoInventarioHardware


FROM v_R_System rs


----------------------------------------------------------------
-- SISTEMA OPERACIONAL
----------------------------------------------------------------

LEFT JOIN v_GS_OPERATING_SYSTEM os
    ON os.ResourceID = rs.ResourceID


----------------------------------------------------------------
-- COMPUTER SYSTEM
----------------------------------------------------------------

LEFT JOIN v_GS_COMPUTER_SYSTEM cs
    ON cs.ResourceID = rs.ResourceID


----------------------------------------------------------------
-- PROCESSADOR
----------------------------------------------------------------

LEFT JOIN CPU cpu
    ON cpu.ResourceID = rs.ResourceID


----------------------------------------------------------------
-- MEMÓRIA RAM
----------------------------------------------------------------

LEFT JOIN RAM ram
    ON ram.ResourceID = rs.ResourceID


----------------------------------------------------------------
-- BIOS
----------------------------------------------------------------

LEFT JOIN v_GS_PC_BIOS bios
    ON bios.ResourceID = rs.ResourceID


----------------------------------------------------------------
-- TPM
----------------------------------------------------------------

LEFT JOIN v_GS_TPM tpm
    ON tpm.ResourceID = rs.ResourceID


----------------------------------------------------------------
-- REDE
----------------------------------------------------------------

LEFT JOIN REDE net
    ON net.ResourceID = rs.ResourceID


----------------------------------------------------------------
-- DISCO C:
----------------------------------------------------------------

LEFT JOIN v_GS_LOGICAL_DISK disk
    ON disk.ResourceID = rs.ResourceID
   AND disk.DeviceID0 = 'C:'


----------------------------------------------------------------
-- BITLOCKER
----------------------------------------------------------------

LEFT JOIN v_GS_ENCRYPTABLE_VOLUME bit
    ON bit.ResourceID = rs.ResourceID
   AND bit.DriveLetter0 = 'C:'


----------------------------------------------------------------
-- CHASSI
----------------------------------------------------------------

LEFT JOIN v_GS_SYSTEM_ENCLOSURE se
    ON se.ResourceID = rs.ResourceID


----------------------------------------------------------------
-- DATA DO ÚLTIMO HARDWARE INVENTORY
----------------------------------------------------------------

LEFT JOIN v_GS_WORKSTATION_STATUS hw
    ON hw.ResourceID = rs.ResourceID


----------------------------------------------------------------
-- SOMENTE EQUIPAMENTOS NÃO OBSOLETOS
----------------------------------------------------------------

WHERE rs.Obsolete0 = 0

ORDER BY rs.Name0;
