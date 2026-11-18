# frozen_string_literal: true

require "time"

module Biblioteca
  class Erro < StandardError; end

  class ErroValidacao < Erro
    attr_reader :erros

    def initialize(erros)
      @erros = erros
      super(erros.join(" "))
    end
  end

  class LivroNaoEncontrado < Erro
    def initialize(id)
      super("Nenhum livro com o código #{id}.")
    end
  end

  class ErroArquivo < Erro; end

  # Funções de texto usadas em buscas e agrupamentos:
  # "Ficção" e "ficcao" viram a mesma chave.
  module Texto
    module_function

    def normalizar(texto)
      texto.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip
    end

    def limpar(texto)
      valor = texto.to_s.strip.squeeze(" ")
      valor.empty? ? nil : valor
    end
  end

  # Classe base dos registros salvos: guarda id e datas, e define o
  # "contrato" de validação que as subclasses precisam cumprir.
  class Registro
    attr_reader :id, :criado_em, :atualizado_em

    def initialize(id: nil, criado_em: nil, atualizado_em: nil)
      @id = id
      @criado_em = criado_em || Time.now.iso8601
      @atualizado_em = atualizado_em || @criado_em
    end

    # Cada subclasse diz quais são os seus erros.
    def erros
      raise NotImplementedError, "#{self.class} precisa implementar #erros"
    end

    def valido?
      erros.empty?
    end

    def validar!
      raise ErroValidacao, erros unless valido?

      self
    end

    def to_h
      { id: id, criado_em: criado_em, atualizado_em: atualizado_em }
    end
  end
end
