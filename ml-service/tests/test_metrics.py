import numpy as np
import pytest

from umkm_ml.metrics import mae, mape, rmse, wape, zero_ratio


def test_mae_dan_rmse_nilai_sederhana():
    actual = [2, 4, 6]
    predicted = [1, 4, 8]
    assert mae(actual, predicted) == pytest.approx((1 + 0 + 2) / 3)
    assert rmse(actual, predicted) == pytest.approx(np.sqrt((1 + 0 + 4) / 3))


def test_mape_mengabaikan_hari_bernilai_nol():
    # Hari kedua aktualnya 0 -> tidak boleh menyebabkan pembagian nol.
    actual = [10, 0, 20]
    predicted = [11, 3, 18]
    assert mape(actual, predicted) == pytest.approx((0.1 + 0.1) / 2)


def test_mape_none_bila_semua_aktual_nol():
    assert mape([0, 0, 0], [1, 2, 3]) is None


def test_zero_ratio():
    assert zero_ratio([0, 0, 5, 5]) == pytest.approx(0.5)


def test_wape_tidak_meledak_pada_nilai_kecil():
    # Hari dengan penjualan 1 buah membuat MAPE besar, WAPE tetap wajar.
    actual = [100, 100, 1]
    predicted = [90, 90, 2]

    assert wape(actual, predicted) == pytest.approx(21 / 201)
    # MAPE terlihat jauh lebih buruk karena hari bernilai 1 dihitung setara
    assert mape(actual, predicted) > wape(actual, predicted)


def test_wape_none_bila_total_aktual_nol():
    assert wape([0, 0], [1, 2]) is None


def test_panjang_berbeda_ditolak():
    with pytest.raises(ValueError):
        mae([1, 2], [1, 2, 3])
