import type { Messages } from '@/i18n'

/** Textos das telas de administração (usuários, grupos, listas de endereços) em português do Brasil. */
export default {
  "admin": {
    "update": "Atualizar",
    "fields": {
      "id": "Id",
      "alias": "Apelido",
      "hostname": "Nome do computador",
      "login": "Login",
      "platform": "Plataforma",
      "username": "Usuário",
      "password": "Senha",
      "confirm": "Confirmar",
      "email": "E-mail",
      "administrator": "Administrador",
      "group": "Grupo",
      "guid": "Guid",
      "name": "Nome",
      "note": "Anotação",
      "status": "Status",
      "admin": "Admin",
      "user": "Usuário",
      "rights": "Permissões"
    },
    "users": {
      "add": "Adicionar usuário",
      "edit": "Editar usuário",
      "active": "Ativo",
      "inactive": "Inativo",
      "activate": "Ativar",
      "deactivate": "Desativar",
      "copied": "Copiado!",
      "fillAll": "Preencha todos os campos",
      "mismatch": "A senha e a confirmação não coincidem",
      "addFailed": "Não foi possível adicionar o usuário",
      "updateFailed": "Não foi possível atualizar o usuário",
      "activateFailed": "Não foi possível ativar o usuário {name}",
      "deactivateFailed": "Não foi possível desativar o usuário {name}",
      "confirmDelete": "Tem certeza de que deseja excluir este usuário?",
      "deleted": "Usuário excluído com sucesso",
      "deleteFailed": "Não foi possível excluir o usuário"
    },
    "groups": {
      "add": "Adicionar grupo",
      "update": "Atualizar grupo",
      "name": "Nome do grupo",
      "confirmDelete": "Tem certeza de que deseja excluir este grupo?",
      "canConnectTo": "Pode se conectar a",
      "canBeReachedBy": "Pode ser acessado por"
    },
    "ab": {
      "personal": "Lista de endereços pessoal",
      "createShared": "Criar uma lista de endereços compartilhada",
      "addShared": "Adicionar lista de endereços compartilhada",
      "sharedName": "Nome da lista de endereços compartilhada",
      "update": "Atualizar lista de endereços",
      "name": "Nome da lista de endereços",
      "viewRules": "Ver regras",
      "addRule": "Adicionar regra",
      "edit": "Editar lista de endereços",
      "delete": "Excluir lista de endereços",
      "confirmDelete": "Tem certeza de que deseja excluir esta lista de endereços?",
      "rulesTitle": "Regras",
      "addRuleFor": "Adicionar regra para {ab}",
      "nullOption": "Nenhum",
      "ruleError": "O usuário deve ficar vazio em uma regra de grupo, e o grupo vazio em uma regra de usuário",
      "rights": {
        "none": "Nenhuma",
        "read": "Leitura",
        "write": "Escrita",
        "full": "Controle total"
      },
      "viewRights": {
        "none": "Nenhuma",
        "read": "Leitura",
        "readWrite": "Leitura/escrita",
        "total": "Controle total",
        "unknown": "Desconhecida"
      }
    }
  }
} as Messages
