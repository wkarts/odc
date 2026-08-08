<?php
declare(strict_types=1);
if ($argc < 3) { fwrite(STDERR, "Uso: php -d phar.readonly=0 build-php-phar.php <root> <saida.phar>\n"); exit(2); }
$root = realpath($argv[1]);
$out = $argv[2];
if ($root === false) { throw new RuntimeException('Root inválido'); }
@unlink($out);
$phar = new Phar($out, 0, 'odc-php.phar');
$phar->startBuffering();
$phar->addFile($root.'/src/OdcException.php', 'src/OdcException.php');
$phar->addFile($root.'/src/OdcContainer.php', 'src/OdcContainer.php');
$phar->addFile($root.'/bin/odc', 'bin/odc');
$stub = <<<'PHP'
#!/usr/bin/env php
<?php
Phar::mapPhar('odc-php.phar');
require 'phar://odc-php.phar/bin/odc';
__HALT_COMPILER();
PHP;
$phar->setStub($stub);
$phar->setSignatureAlgorithm(Phar::SHA256);
$phar->stopBuffering();
chmod($out, 0755);
echo "Gerado: {$out}\n";
