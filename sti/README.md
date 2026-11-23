# Somos STI Acesso Remoto

Ferramenta de acesso remoto da STI Solutions: servidor de conexão, painel de administração e programa
cliente, com a marca Somos STI e rodando em infraestrutura própria.

Este repositório é uma cópia (fork) do [SCTGDesk](https://github.com/sctg-development/sctgdesk-server),
que por sua vez deriva do [RustDesk](https://github.com/rustdesk/rustdesk). Não é afiliado a nenhum dos
dois projetos. Licença: **AGPL-3.0** (arquivo `LICENSE`).

## Como o repositório está organizado

A regra é simples: **o código de origem fica intacto e tudo o que é da STI fica separado e identificado**.
Assim dá para receber as correções de segurança do projeto de origem sem retrabalho.

| Onde | O que é |
|---|---|
| `sti/` | Tudo o que é só da STI: esta documentação, a marca e os arquivos do servidor |
| `sti/marca/` | Ícone e logo oficiais usados no painel e no programa |
| `sti/servidor/` | Instalação e atualização do servidor da STI |
| `.github/workflows/sti-*.yml` | Compilações da STI no GitHub Actions |
| `web/console/sti-tema.cjs` | Cores da marca no painel (um arquivo só) |
| `web/console/src/i18n/locales/pt-BR/` | Textos do painel em português do Brasil |
| Todo o resto | Código de origem, sem alteração de comportamento |

### Alterações feitas em arquivos de origem

São poucas e pequenas, de propósito. Cada uma está marcada com um comentário "Somos STI" quando o
formato do arquivo permite.

| Arquivo | Alteração |
|---|---|
| `web/console/src/i18n/index.ts` | Registra o idioma `pt-BR` e o torna o padrão |
| `crates/api-state/src/profile.rs` | Aceita `pt-BR` como idioma salvo no perfil do usuário |
| `crates/api-utils/src/types.rs` | Documentação da lista de idiomas |
| `src/main.rs` | Variável `API_ADDRESS`: permite a API e o painel escutarem só em `127.0.0.1`, atrás do proxy HTTPS |
| `web/console/tailwind.config.cjs` | Carrega a paleta de `sti-tema.cjs` |
| `web/console/src/views/LoginPage.vue` | Logo da STI na tela de login |
| `web/console/src/components/ConnectButtons.vue` | Ícone da STI no botão de conexão |
| `web/console/index.html`, `public/*` | Título, ícones e cores da aba do navegador |

## Versões

- A versão do código de origem continua em `Cargo.toml` (por exemplo `1.1.16-sctg.9`). Não mexemos nela.
- A versão da STI fica em `sti/VERSAO` (`<ano>.<mês>.<sequência>`) e vira a release `sti-v<versão>`, por exemplo `sti-v2026.11.1`.

## Gerar uma versão do servidor

```bash
git checkout sti
echo 2026.11.2 > sti/VERSAO          # sempre um número maior que o anterior
git commit -am "Versão 2026.11.2" && git push origin sti
```

O push do arquivo `sti/VERSAO` faz o GitHub Actions compilar sozinho. Ao terminar, a release `sti-v2026.11.1` terá o pacote e o arquivo
`SHA256SUMS`.

## Receber atualizações do projeto de origem

```bash
git remote add origem https://github.com/sctg-development/sctgdesk-server   # só na primeira vez
git fetch origem
git checkout sti
git merge origem/tcpserver-master-build
```

Conflitos, se houver, ficam restritos aos arquivos da tabela acima. Depois do merge:

```bash
cd web/console && npm ci && npm run build     # o painel compila?
cd ../.. && DATABASE_URL=sqlite://$(pwd)/db_v2.sqlite3 cargo build --locked --bin hbbs
```

Se o projeto de origem tiver criado textos novos no painel, eles aparecem em inglês até serem traduzidos
em `pt-BR` (nunca como chave crua).

## Licença e obrigações

- O código precisa continuar aberto: quem usa o painel ou recebe o programa tem direito ao código-fonte.
  Mantenha este repositório público e o link dele no rodapé do painel.
- Os créditos dos autores originais ficam onde estão (cabeçalhos dos arquivos e rodapé do painel).
- Chaves, senhas e tokens **nunca** entram no repositório. A chave privada do servidor (`id_ed25519`)
  existe só no servidor e no backup.
