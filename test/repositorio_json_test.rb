# frozen_string_literal: true

require_relative "test_helper"

class RepositorioJsonTest < Minitest::Test
  include Biblioteca
  include Fabrica

  def com_arquivo
    Dir.mktmpdir { |pasta| yield File.join(pasta, "dados", "biblioteca.json") }
  end

  def test_arquivo_inexistente_comeca_vazio
    com_arquivo { |caminho| assert_equal [], RepositorioJson.new(caminho).carregar }
  end

  def test_salva_e_carrega_mantendo_os_dados
    com_arquivo do |caminho|
      repositorio = RepositorioJson.new(caminho)
      acervo = acervo_de_exemplo
      repositorio.salvar(acervo)

      carregados = repositorio.carregar
      assert_equal acervo.map(&:to_h), carregados.map(&:to_h)
      assert_equal 1, JSON.parse(File.read(caminho))["versao"]
      refute File.exist?("#{caminho}.tmp")
    end
  end

  def test_callback_salva_a_cada_alteracao
    com_arquivo do |caminho|
      repositorio = RepositorioJson.new(caminho)
      acervo = Acervo.new.ao_alterar { repositorio.salvar(acervo) }

      acervo.adicionar(titulo: "Duna", autor: "Frank Herbert")
      assert_equal ["Duna"], repositorio.carregar.map(&:titulo)

      acervo.remover(1)
      assert_empty repositorio.carregar
    end
  end

  def test_json_invalido_gera_erro_claro
    com_arquivo do |caminho|
      FileUtils.mkdir_p(File.dirname(caminho))
      File.write(caminho, "{ quebrado")
      erro = assert_raises(ErroArquivo) { RepositorioJson.new(caminho).carregar }
      assert_match "não é um JSON válido", erro.message

      File.write(caminho, '{"livros":[{"titulo":"","autor":"X"}]}')
      assert_raises(ErroArquivo) { RepositorioJson.new(caminho).carregar }
    end
  end

  def test_arquivo_de_exemplo_e_valido
    livros = RepositorioJson.new(File.expand_path("../data/exemplo.json", __dir__)).carregar
    assert_equal 15, livros.size
  end
end
