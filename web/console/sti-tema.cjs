/*
 * Somos STI Acesso Remoto - cores do painel.
 *
 * O painel original usa a paleta "indigo" do Tailwind em todos os botoes, links e destaques.
 * Em vez de editar cada tela, trocamos a paleta inteira aqui: assim as telas ficam iguais as
 * do projeto de origem (facil de atualizar) e a cor da marca muda em um lugar so.
 *
 * Cores oficiais do kit de identidade: azul-marinho #071426, ciano #21B1C9, azul secundario #157591.
 */
module.exports = {
  indigo: {
    50: '#ecfbfd',
    100: '#d0f3f9',
    200: '#a6e7f2',
    300: '#6bd4e7',
    400: '#21B1C9', // ciano oficial
    500: '#1a97b0',
    600: '#157591', // azul secundario oficial: botoes e links
    700: '#135f77',
    800: '#144f62',
    900: '#0f3a4a',
    950: '#071426', // azul-marinho oficial
  },
}
