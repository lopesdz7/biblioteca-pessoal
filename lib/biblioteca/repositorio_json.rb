# frozen_string_literal: true

require "json"
require "fileutils"

module Biblioteca
  # Lê e grava os livros em um arquivo JSON, mantendo os dados entre execuções.
  class RepositorioJson
    VERSAO = 1

    attr_reader :caminho

    def initialize(caminho)
      @caminho = caminho
    end

    def carregar
      return [] unless File.exist?(caminho)

      dados = JSON.parse(File.read(caminho, encoding: "UTF-8"))
      lista = dados.is_a?(Hash) ? dados.fetch("livros", []) : dados
      lista.map { |item| carregar_livro(item) }
    rescue JSON::ParserError => e
      raise ErroArquivo, "O arquivo #{caminho} não é um JSON válido: #{e.message.lines.first.strip}"
    end

    # Grava em um arquivo temporário e depois troca, para não corromper
    # os dados se o programa for interrompido no meio da gravação.
    def salvar(livros)
      FileUtils.mkdir_p(File.dirname(caminho))
      temporario = "#{caminho}.tmp"
      conteudo = JSON.pretty_generate({ versao: VERSAO, livros: livros.map(&:to_h) })
      File.write(temporario, "#{conteudo}\n", encoding: "UTF-8")
      File.rename(temporario, caminho)
    end

    private

    def carregar_livro(item)
      Livro.from_h(item).validar!
    rescue ErroValidacao, ArgumentError => e
      raise ErroArquivo, "Livro inválido em #{caminho} (#{item.inspect[0, 60]}...): #{e.message}"
    end
  end
end
