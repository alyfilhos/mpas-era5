# Seleção ERA5 do primeiro caso global

Estes arquivos preservam a seleção aprovada, não os dados. A baseline é a
reanálise global de **2014-09-10 00:00 UTC**, em GRIB, na grade regular
latitude/longitude padrão do CDS, sem `area`, `grid` ou reinterpolação no
request final.

| Configuração | Dataset CDS | Conteúdo |
|---|---|---|
| `pressure-levels.json` | `reanalysis-era5-pressure-levels` | 5 variáveis em todos os 37 níveis isobáricos ERA5 |
| `single-levels.json` | `reanalysis-era5-single-levels` | 19 campos de superfície, solo, SST substituta, neve e gelo |

Os 37 níveis de pressão, somados ao nível especial de superfície produzido
pelo WPS, explicam `config_nfglevels=38`. O número 38 não representa 38
níveis de pressão do ERA5.

## Probe e download

O probe mantém todas as variáveis e níveis da baseline, mas acrescenta
temporariamente a área de 1°N, 0°W, 0°N, 1°E. Isso reduz o volume e valida
credencial, termos, datasets, nomes de parâmetros e transporte GRIB. A área do
probe está versionada em `probe_area`; ela nunca é incorporada ao request
final.

Depois de criar `~/.cdsapirc` conforme a documentação oficial e aceitar os
termos dos dois datasets no portal CDS:

```sh
./scripts/data/fetch-era5.sh build
./scripts/data/fetch-era5.sh config
./scripts/data/fetch-era5.sh probe
./scripts/data/fetch-era5.sh download
./scripts/validate/era5.sh
```

O wrapper monta a credencial somente como arquivo read-only em runtime. O
token não é copiado para a imagem, passado em argumento/variável nem incluído
nas configurações. `CDSAPI_RC_FILE` pode apontar para outra credencial local
regular, desde que ela não seja um symlink.

Os outputs locais são:

```text
data/era5/2014-09-10_00/
├── era5-pressure-levels.grib
├── era5-single-levels.grib
└── manifest.json
```

O cliente baixa para um arquivo temporário no mesmo filesystem, valida a
estrutura GRIB e só então promove o arquivo de forma atômica. Uma reexecução
aceita apenas um arquivo cujo tamanho e SHA-256 coincidam com o manifesto;
conteúdo divergente nunca é sobrescrito silenciosamente.

O ciclo 0010 validou aquisição e transporte. No ciclo 0011, o inventário
semântico real casou integralmente a `Vtable.ECMWF` upstream e os dois GRIBs
foram convertidos e combinados. A configuração correspondente está em
[`../wps/`](../wps/); `init.nc` permanece fora desse ciclo.
