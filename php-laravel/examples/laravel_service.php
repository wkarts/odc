<?php

namespace App\Services;

use Odc\OdcContainer;

final class OdcStorageService
{
    public function store(string $sourceFile, string $destinationOdc, array $metadata = []): string
    {
        OdcContainer::createFromFile($sourceFile, $destinationOdc, $metadata, true);
        return $destinationOdc;
    }

    public function info(string $odcPath): array
    {
        return OdcContainer::info($odcPath);
    }

    public function extract(string $odcPath, string $destination): void
    {
        OdcContainer::extract($odcPath, $destination);
    }
}
