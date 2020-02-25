f = open('aliasi.txt', 'r') 

lista_aliasa = f.read().split()

f.close()
f1 = open('script.sql', 'w')

def concat():
    str_const = 'INSERT INTO alias (alias, predmet_id, smjer_id) VALUES ' 

    niz_predmeta = [[1, 3], [2, 3], [7, 3], [7, 2], [9, 3], [10, 3], [12, 3], [16, 3],
                    [18, 3], [20, 3], [24, 3], [27, 3], [26, 3], [29, 3], [33, 3], [35, 3],
                    [36, 3], [38, 3], [23, 2], [33, 10], [13, 10]] # niz parova (predmet, smjer) za generisanje sifri po 

    final = ''
    p = 0
    for predmet in niz_predmeta:
        final += str_const
        for i in range(p, p+40): # opcionalan broj sifara, u ovom slucaju 40
            final += '(\'' + str(lista_aliasa[i]) + '\',' + str(predmet[0]) + ',' + str(predmet[1]) + ')'
            if i == p+39:
                final += ';'
            else:
                final += ','
        final += '\n'
        p += 40
    return final


f1.close()
