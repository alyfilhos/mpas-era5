# WPS/ungrib do primeiro caso global

Este diretório versiona somente a configuração reproduzível do `ungrib`.
Os GRIBs, logs e arquivos WPS intermediate permanecem sob `data/` e fora do
Git.

Pressure levels e single levels são processados em workspaces independentes:

```text
pressure/namelist.wps → prefix ERA5_PRES
single/namelist.wps   → prefix ERA5_SFC
```

Ambos usam a `Vtable.ECMWF` upstream instalada pelo WPS 4.7.0. A tabela não é
copiada para o repositório; o wrapper cria apenas um link simbólico temporário
para o arquivo read-only da imagem.

Para executar e validar:

```sh
./scripts/run/ungrib-era5.sh
./scripts/validate/wps-era5.sh
```

O resultado local validado é:

```text
data/cases/first-global-240km/wps/
├── ERA5_PRES:2014-09-10_00
├── ERA5_SFC:2014-09-10_00
├── ERA5:2014-09-10_00
├── ungrib-pressure.log
├── ungrib-single.log
└── manifest.json
```

O validador cruza requests, framing/g1print, Vtable, logs e headers version 5.
Ele exige 185 + 19 = 204 registros, 37 níveis nos campos 3-D e todos os campos
funcionais superficiais da baseline. O ciclo termina no combined; não executa
`geogrid`, `metgrid` nem o modo meteorológico do `init_atmosphere_model`.
