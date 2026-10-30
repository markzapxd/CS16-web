# CS16 Web

Counter-Strike 1.6 no navegador, com o mapa **Garten** e inicialização pelo Docker Compose.

## Iniciar

Requer **Git**, **Docker com Compose** e acesso à internet.

```bash
git clone https://github.com/markzapxd/CS16-web.git
cd CS16-web
docker compose up -d
```

Acesse **http://localhost:8080** ou **http://IP-DO-SERVIDOR:8080**.

Na primeira inicialização, os dados do jogo são baixados e preparados automaticamente. Aguarde a conclusão; reserve cerca de **2 GB livres além das imagens**. Não é necessário criar `.env` nem copiar o mapa.

## Acesso pela rede

O servidor HTTP escuta em `0.0.0.0:8080`. Libere estas portas no firewall:

| Porta | Uso |
| --- | --- |
| `8080/TCP` | Página e conexão WebSocket |
| `27018/UDP` e `27018/TCP` | WebRTC |

O endereço anunciado é obtido automaticamente do endereço usado para abrir a página. Roteadores, NAT e proxies podem exigir ajustes: veja [NETWORKING.md](NETWORKING.md).

## Comandos úteis

```bash
# Acompanhar a preparação e os logs
docker compose logs -f

# Parar sem apagar os dados
docker compose down

# Aplicar atualizações do repositório
git pull
docker compose up -d
```

> `docker compose down -v` apaga o volume de dados e exige um novo download.

## Mapas customizados

O Garten já acompanha o repositório em `custom-content/cstrike/maps/`.

Para adicionar conteúdo:

1. Coloque mapas e recursos em `custom-content/cstrike/`, preservando as pastas `maps`, `models`, `sound` etc.
2. Liste o BSP e suas dependências em `custom-content/preload.json`.
3. Ajuste `MAP` no `docker-compose.yaml` e recrie o container com `docker compose up -d --force-recreate cs16`.

**Limitação conhecida:** faltam seis modelos de veículos do Garten. O mapa é jogável, mas esses objetos não são exibidos corretamente. O preload não acompanha trocas de mapa durante a partida automaticamente.

## Imagem e fontes

A imagem é compilada a partir das fontes e publicada no [GHCR](https://github.com/markzapxd/CS16-web/pkgs/container/cs16-web%2Fsource-cs16), sem usar uma imagem de servidor CS de terceiros como base. O Compose fixa a versão por digest.

Para compilar localmente, opcionalmente:

```bash
docker build -t cs16-web:source .
CS16_IMAGE=cs16-web:source docker compose up -d
```

Baseado em [Xash3D FWGS](https://github.com/FWGS/xash3d-fwgs), [CS16 Client](https://github.com/FWGS/cs16-client), [Go bindings](https://github.com/jklenner/goxash3d-fwgs) e [WebXash3D](https://github.com/sealdev224/webxash3d-fwgs-cstrike). As revisões estão fixadas no Dockerfile; a licença das fontes vendorizadas está em [vendor/LICENSE.md](vendor/LICENSE.md). Dados Valve e mapas de terceiros têm direitos e condições próprios.
