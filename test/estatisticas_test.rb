# frozen_string_literal: true

require_relative "test_helper"

class EstatisticasTest < Minitest::Test
  include Biblioteca
  include Fabrica

  def setup
    @estatisticas = Estatisticas.new(acervo_de_exemplo)
  end

  def test_resumo_geral
    resumo = @estatisticas.resumo

    assert_equal 6, resumo[:total]
    assert_equal({ nao_lido: 2, lendo: 1, lido: 3 }, resumo[:por_status])
    assert_equal ["Ficção científica", 3], resumo[:por_categoria].first
    assert_includes resumo[:por_categoria], ["Sem categoria", 1]
    assert_equal 4.7, resumo[:media_avaliacao]
    assert_equal 3, resumo[:avaliados]
  end

  def test_media_vazia_sem_avaliacoes
    assert_nil Estatisticas.new([]).resumo[:media_avaliacao]
  end

  def test_por_autor_em_ordem_decrescente
    autores = @estatisticas.por_autor

    assert_equal ["Isaac Asimov", 2], autores.first
    assert_equal 5, autores.size
    assert_equal autores.map(&:last).sort.reverse, autores.map(&:last)
  end

  def test_por_decada
    assert_equal({ decadas: [[1940, 1], [1950, 2], [1960, 1], [2000, 1]], sem_ano: 1 },
                 @estatisticas.por_decada)
  end

  def test_top_so_com_lidos_avaliados_da_maior_nota
    assert_equal ["1984", "Fundação", "Eu, Robô"], @estatisticas.top.map(&:titulo)
    assert_equal 1, @estatisticas.top(1).size
  end
end
